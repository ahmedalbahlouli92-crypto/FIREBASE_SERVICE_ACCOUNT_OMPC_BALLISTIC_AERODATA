using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Microsoft.Win32;

namespace OmpcBallisticAeroData
{
    class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            int port = 8080;
            string url = "http://localhost:" + port + "/";

            // Check if server is responding
            bool serverReady = IsPortListening(port);

            if (!serverReady)
            {
                // Try starting background server
                string webDir = Path.Combine(baseDir, "build", "web");
                if (Directory.Exists(webDir))
                {
                    try
                    {
                        ProcessStartInfo srvInfo = new ProcessStartInfo
                        {
                            FileName = "npx.cmd",
                            Arguments = "serve -s \"" + webDir + "\" -l " + port,
                            WorkingDirectory = baseDir,
                            WindowStyle = ProcessWindowStyle.Hidden,
                            CreateNoWindow = true,
                            UseShellExecute = false
                        };
                        Process.Start(srvInfo);
                        
                        // Wait up to 5 seconds for server to be responsive
                        for (int i = 0; i < 25; i++)
                        {
                            Thread.Sleep(200);
                            if (IsPortListening(port)) break;
                        }
                    }
                    catch { }
                }
            }

            // Launch in dedicated standalone app window
            string browserExe = FindChromiumBrowser();
            if (browserExe != null)
            {
                ProcessStartInfo appInfo = new ProcessStartInfo
                {
                    FileName = browserExe,
                    Arguments = string.Format("--app=\"{0}\" --start-maximized", url),
                    UseShellExecute = true
                };
                Process.Start(appInfo);
            }
            else
            {
                Process.Start(url);
            }
        }

        static bool IsPortListening(int port)
        {
            try
            {
                using (TcpClient client = new TcpClient())
                {
                    var result = client.BeginConnect("127.0.0.1", port, null, null);
                    bool success = result.AsyncWaitHandle.WaitOne(500);
                    if (!success) return false;
                    client.EndConnect(result);
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }

        private static string FindChromiumBrowser()
        {
            // 1. Check Windows Registry App Paths (covers 32-bit, 64-bit, and user-level installations)
            string[] registryKeys = new string[]
            {
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
                @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
                @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\brave.exe"
            };

            foreach (string regKey in registryKeys)
            {
                try
                {
                    using (var key = Registry.LocalMachine.OpenSubKey(regKey))
                    {
                        if (key != null)
                        {
                            object val = key.GetValue(null) ?? key.GetValue("");
                            if (val != null && File.Exists(val.ToString()))
                                return val.ToString();
                        }
                    }
                }
                catch { }

                try
                {
                    using (var key = Registry.CurrentUser.OpenSubKey(regKey))
                    {
                        if (key != null)
                        {
                            object val = key.GetValue(null) ?? key.GetValue("");
                            if (val != null && File.Exists(val.ToString()))
                                return val.ToString();
                        }
                    }
                }
                catch { }
            }

            // 2. Check Standard Directory Paths
            string[] candidates = new string[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"BraveSoftware\Brave-Browser\Application\brave.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"BraveSoftware\Brave-Browser\Application\brave.exe")
            };

            foreach (string candidate in candidates)
            {
                if (!string.IsNullOrEmpty(candidate) && File.Exists(candidate))
                    return candidate;
            }

            // 3. Check system PATH via where command
            string[] exes = new string[] { "msedge.exe", "chrome.exe", "brave.exe" };
            foreach (string exe in exes)
            {
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = "where",
                        Arguments = exe,
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        CreateNoWindow = true
                    };
                    using (var p = Process.Start(psi))
                    {
                        string output = p.StandardOutput.ReadLine();
                        p.WaitForExit(1000);
                        if (!string.IsNullOrEmpty(output) && File.Exists(output.Trim()))
                            return output.Trim();
                    }
                }
                catch { }
            }

            return null;
        }
    }
}
