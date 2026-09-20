using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Diagnostics;
using System.Threading;
using Microsoft.Win32;

namespace OmpcBallisticAeroData
{
    class Program
    {
        private static TcpListener _tcpListener;
        private static string _webRoot;
        private static int _port = 0;
        private static Process _browserProcess;

        [STAThread]
        static void Main(string[] args)
        {
            // Resolve web directory relative to executable
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            _webRoot = Path.Combine(baseDir, "build", "web");

            if (!Directory.Exists(_webRoot) || !File.Exists(Path.Combine(_webRoot, "index.html")))
            {
                // Also check if running directly inside build/web or alongside web files
                if (File.Exists(Path.Combine(baseDir, "index.html")))
                {
                    _webRoot = baseDir;
                }
                else
                {
                    // Attempt automatic self-extraction from embedded resource
                    string unpackedDir;
                    bool extracted = TryExtractEmbeddedWebBundle(out unpackedDir);
                    if (extracted && Directory.Exists(unpackedDir) && File.Exists(Path.Combine(unpackedDir, "index.html")))
                    {
                        _webRoot = unpackedDir;
                    }
                    else
                    {
                        System.Windows.Forms.MessageBox.Show(
                            "Cannot find the web application assets in 'build/web' or current folder.\n" +
                            "Please ensure the application folder is intact.",
                            "OMPC Ballistic AeroData - Error",
                            System.Windows.Forms.MessageBoxButtons.OK,
                            System.Windows.Forms.MessageBoxIcon.Error);
                        return;
                    }
                }
            }

            // Bind loopback socket server on an automatically allocated free port (Zero Admin Privileges required)
            try
            {
                _tcpListener = new TcpListener(IPAddress.Loopback, 0);
                _tcpListener.Start();
                _port = ((IPEndPoint)_tcpListener.LocalEndpoint).Port;
            }
            catch (Exception ex)
            {
                System.Windows.Forms.MessageBox.Show(
                    "Could not initialize local loopback socket: " + ex.Message,
                    "OMPC Ballistic AeroData - Error",
                    System.Windows.Forms.MessageBoxButtons.OK,
                    System.Windows.Forms.MessageBoxIcon.Error);
                return;
            }

            // Start background listener thread
            Thread serverThread = new Thread(ListenLoop);
            serverThread.IsBackground = true;
            serverThread.Start();
            Thread.Sleep(100);

            // Launch purely offline local instance with instant zero-latency loading
            string appUrl = "http://127.0.0.1:" + _port + "/";
            string userDataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OMPC_Ballistic_AeroData", "browser_profile");
            try { Directory.CreateDirectory(userDataDir); } catch { }

            string browserExe = FindChromiumBrowser();

            if (browserExe != null)
            {
                try
                {
                    // Critical flags for Windows 7 / older GPUs (Intel HD 4600):
                    // --disable-gpu and --disable-gpu-compositing prevent the black screen crash on older drivers
                    // --no-sandbox ensures it runs smoothly even if elevated or under UAC
                    string browserArgs = string.Format(
                        "--app=\"{0}\" " +
                        "--user-data-dir=\"{1}\" " +
                        "--start-maximized " +
                        "--new-window " +
                        "--no-first-run " +
                        "--no-default-browser-check " +
                        "--disable-first-run-ui " +
                        "--disable-notifications " +
                        "--disable-gpu " +
                        "--disable-gpu-compositing " +
                        "--disable-software-rasterizer " +
                        "--no-sandbox " +
                        "--disable-features=msEdgeSidebarV2,msHub,msHubEdgeShopping,Translate,OptimizationHints,MediaRouter " +
                        "--disable-extensions " +
                        "--disable-background-networking " +
                        "--disable-sync " +
                        "--disable-default-apps",
                        appUrl, userDataDir);

                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = browserExe,
                        Arguments = browserArgs,
                        UseShellExecute = false
                    };
                    _browserProcess = Process.Start(psi);
                }
                catch
                {
                    try
                    {
                        // Fallback to launching browserExe directly in app mode with shell execute
                        ProcessStartInfo simplePsi = new ProcessStartInfo
                        {
                            FileName = browserExe,
                            Arguments = string.Format("--app=\"{0}\" --start-maximized --disable-gpu", appUrl),
                            UseShellExecute = true
                        };
                        _browserProcess = Process.Start(simplePsi);
                    }
                    catch
                    {
                        Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
                    }
                }
            }
            else
            {
                Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
            }

            // Keep server alive while app window is open
            if (_browserProcess != null)
            {
                bool quickExit = _browserProcess.WaitForExit(4000);
                if (!quickExit)
                {
                    _browserProcess.WaitForExit();
                }
                else
                {
                    Thread.Sleep(Timeout.Infinite);
                }
            }
            else
            {
                Thread.Sleep(Timeout.Infinite);
            }

            try { _tcpListener.Stop(); } catch { }
        }

        private static void ListenLoop()
        {
            while (true)
            {
                try
                {
                    TcpClient client = _tcpListener.AcceptTcpClient();
                    ThreadPool.QueueUserWorkItem(ProcessClient, client);
                }
                catch
                {
                    break;
                }
            }
        }

        private static void ProcessClient(object state)
        {
            TcpClient client = (TcpClient)state;
            try
            {
                client.ReceiveTimeout = 4000;
                client.SendTimeout = 4000;
                using (NetworkStream stream = client.GetStream())
                {
                    byte[] buffer = new byte[4096];
                    int bytesRead = stream.Read(buffer, 0, buffer.Length);
                    if (bytesRead <= 0) return;

                    string request = Encoding.ASCII.GetString(buffer, 0, bytesRead);
                    int firstLineEnd = request.IndexOf("\r\n");
                    if (firstLineEnd < 0) return;
                    string requestLine = request.Substring(0, firstLineEnd);

                    string[] parts = requestLine.Split(' ');
                    if (parts.Length < 2) return;

                    string rawUrl = parts[1];
                    int qIdx = rawUrl.IndexOf('?');
                    if (qIdx >= 0) rawUrl = rawUrl.Substring(0, qIdx);
                    if (rawUrl == "/" || string.IsNullOrEmpty(rawUrl))
                    {
                        rawUrl = "/index.html";
                    }

                    string cleanPath = Uri.UnescapeDataString(rawUrl).TrimStart('/');
                    cleanPath = cleanPath.Replace('/', Path.DirectorySeparatorChar);
                    string fullPath = Path.Combine(_webRoot, cleanPath);
                    if (!File.Exists(fullPath))
                    {
                        fullPath = Path.Combine(_webRoot, "index.html");
                    }

                    if (File.Exists(fullPath))
                    {
                        byte[] bytes = File.ReadAllBytes(fullPath);
                        string mime = GetMimeType(Path.GetExtension(fullPath));
                        string header = string.Format(
                            "HTTP/1.1 200 OK\r\n" +
                            "Content-Type: {0}\r\n" +
                            "Content-Length: {1}\r\n" +
                            "Cache-Control: no-cache\r\n" +
                            "Access-Control-Allow-Origin: *\r\n" +
                            "Connection: close\r\n\r\n",
                            mime, bytes.Length);
                        byte[] headerBytes = Encoding.ASCII.GetBytes(header);
                        stream.Write(headerBytes, 0, headerBytes.Length);
                        stream.Write(bytes, 0, bytes.Length);
                        stream.Flush();
                    }
                    else
                    {
                        string notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                        byte[] nfBytes = Encoding.ASCII.GetBytes(notFound);
                        stream.Write(nfBytes, 0, nfBytes.Length);
                        stream.Flush();
                    }
                }
            }
            catch { }
            finally
            {
                try { client.Close(); } catch { }
            }
        }

        private static string GetMimeType(string ext)
        {
            switch (ext.ToLower())
            {
                case ".html": case ".htm": return "text/html; charset=utf-8";
                case ".js": case ".mjs": return "application/javascript; charset=utf-8";
                case ".wasm": return "application/wasm";
                case ".json": return "application/json";
                case ".css": return "text/css; charset=utf-8";
                case ".png": return "image/png";
                case ".jpg": case ".jpeg": return "image/jpeg";
                case ".ico": return "image/x-icon";
                case ".svg": return "image/svg+xml";
                case ".woff": return "font/woff";
                case ".woff2": return "font/woff2";
                default: return "application/octet-stream";
            }
        }

        private static bool TryExtractEmbeddedWebBundle(out string targetDir)
        {
            try
            {
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                targetDir = Path.Combine(localAppData, "OMPC_Ballistic_AeroData", "web_app");

                var assembly = System.Reflection.Assembly.GetExecutingAssembly();
                string[] resourceNames = assembly.GetManifestResourceNames();
                string zipResourceName = null;
                foreach (string name in resourceNames)
                {
                    if (name.EndsWith("web_bundle.zip", StringComparison.OrdinalIgnoreCase))
                    {
                        zipResourceName = name;
                        break;
                    }
                }

                if (string.IsNullOrEmpty(zipResourceName))
                {
                    return false;
                }

                using (Stream resStream = assembly.GetManifestResourceStream(zipResourceName))
                {
                    if (resStream == null) return false;

                    long resourceLength = resStream.Length;
                    string markerFile = Path.Combine(targetDir, "bundle_size.txt");

                    // Check if already extracted and matches current executable bundle size
                    if (Directory.Exists(targetDir) && File.Exists(Path.Combine(targetDir, "index.html")) && File.Exists(markerFile))
                    {
                        string savedSize = File.ReadAllText(markerFile).Trim();
                        if (savedSize == resourceLength.ToString())
                        {
                            return true;
                        }
                    }

                    // Clean and extract bundle
                    if (Directory.Exists(targetDir))
                    {
                        try { Directory.Delete(targetDir, true); } catch { }
                    }
                    Directory.CreateDirectory(targetDir);

                    string tempZip = Path.Combine(Path.GetTempPath(), "ompc_bundle_" + Guid.NewGuid().ToString("N") + ".zip");
                    using (FileStream fs = new FileStream(tempZip, FileMode.Create, FileAccess.Write))
                    {
                        resStream.CopyTo(fs);
                    }

                    System.IO.Compression.ZipFile.ExtractToDirectory(tempZip, targetDir);
                    try { File.Delete(tempZip); } catch { }
                    try { File.WriteAllText(markerFile, resourceLength.ToString()); } catch { }

                    return true;
                }
            }
            catch
            {
                targetDir = null;
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

