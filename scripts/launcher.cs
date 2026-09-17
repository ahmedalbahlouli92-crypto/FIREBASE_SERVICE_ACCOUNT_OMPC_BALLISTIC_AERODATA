using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;

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
            string edgePath = @"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe";
            if (File.Exists(edgePath))
            {
                ProcessStartInfo appInfo = new ProcessStartInfo
                {
                    FileName = edgePath,
                    Arguments = "--app=" + url + " --window-size=1520,950",
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
    }
}
