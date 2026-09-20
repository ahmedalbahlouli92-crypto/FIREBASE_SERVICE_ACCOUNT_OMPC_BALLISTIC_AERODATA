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
        private static HttpListener _httpListener;
        private static TcpListener _tcpListener;
        private static string _webRoot;
        private static int _port = 8080;
        private static Process _browserProcess;

        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                Log("Starting OMPC Ballistic AeroData at " + DateTime.Now);

                // Resolve web directory relative to executable
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                _webRoot = Path.Combine(baseDir, "build", "web");
                Log("baseDir: " + baseDir + "\r\n_webRoot: " + _webRoot);

                if (!Directory.Exists(_webRoot) || !File.Exists(Path.Combine(_webRoot, "index.html")))
                {
                    if (File.Exists(Path.Combine(baseDir, "index.html")))
                    {
                        _webRoot = baseDir;
                    }
                    else
                    {
                        string unpackedDir;
                        bool extracted = TryExtractEmbeddedWebBundle(out unpackedDir);
                        if (extracted && Directory.Exists(unpackedDir) && File.Exists(Path.Combine(unpackedDir, "index.html")))
                        {
                            _webRoot = unpackedDir;
                        }
                        else
                        {
                            Log("ERROR: Web assets not found!");
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
                Log("Resolved _webRoot: " + _webRoot);

                // Engine 1: Try kernel HttpListener on ports 8080 - 8180 (Best for Windows 10 & 11)
                for (int p = 8080; p < 8180; p++)
                {
                    try
                    {
                        _httpListener = new HttpListener();
                        _httpListener.Prefixes.Add("http://127.0.0.1:" + p + "/");
                        _httpListener.Start();
                        _port = p;
                        Log("HttpListener bound to port: " + _port);
                        break;
                    }
                    catch
                    {
                        if (_httpListener != null)
                        {
                            try { _httpListener.Close(); } catch { }
                            _httpListener = null;
                        }
                    }
                }

                // Engine 2 Fallback: If HttpListener failed (e.g. Windows 7 non-admin without URL ACL), use loopback TcpListener!
                if (_httpListener == null || !_httpListener.IsListening)
                {
                    try
                    {
                        _tcpListener = new TcpListener(IPAddress.Loopback, 0);
                        _tcpListener.Start();
                        _port = ((IPEndPoint)_tcpListener.LocalEndpoint).Port;
                        Log("TcpListener fallback bound to port: " + _port);
                    }
                    catch (Exception ex)
                    {
                        Log("TcpListener failed: " + ex);
                        System.Windows.Forms.MessageBox.Show(
                            "Could not start local server: " + ex.Message,
                            "OMPC Ballistic AeroData - Error",
                            System.Windows.Forms.MessageBoxButtons.OK,
                            System.Windows.Forms.MessageBoxIcon.Error);
                        return;
                    }
                }

                // Start background listener thread
                Thread serverThread = new Thread(ListenLoop);
                serverThread.IsBackground = true;
                serverThread.Start();
                Thread.Sleep(100);

                // Launch local application URL in dedicated window mode
                string appUrl = "http://127.0.0.1:" + _port + "/";
                Log("App URL: " + appUrl);

                string browserExe = FindChromiumBrowser();
                Log("Found browserExe: " + (browserExe ?? "NULL"));

                if (browserExe != null)
                {
                    try
                    {
                        ProcessStartInfo psi = new ProcessStartInfo
                        {
                            FileName = browserExe,
                            Arguments = string.Format("--app=\"{0}\" --start-maximized", appUrl),
                            UseShellExecute = true
                        };
                        Log("Launching browser: " + browserExe + " " + psi.Arguments);
                        _browserProcess = Process.Start(psi);
                        Log("Process.Start returned: " + (_browserProcess != null ? _browserProcess.Id.ToString() : "NULL (shell delegated)"));
                    }
                    catch (Exception ex)
                    {
                        Log("Process.Start exception: " + ex);
                        Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
                    }
                }
                else
                {
                    Log("No browserExe found, opening default URL");
                    Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
                }

                // Keep server running indefinitely while app is active
                Log("Entering wait loop...");
                if (_browserProcess != null)
                {
                    bool quickExit = _browserProcess.WaitForExit(4000);
                    Log("WaitForExit(4000) returned: " + quickExit);
                    if (!quickExit)
                    {
                        _browserProcess.WaitForExit();
                        Log("Browser process exited.");
                    }
                    else
                    {
                        Log("Browser quick exit detected (delegated to existing instance), sleeping infinite...");
                        Thread.Sleep(Timeout.Infinite);
                    }
                }
                else
                {
                    Log("_browserProcess is null (delegated), sleeping infinite...");
                    Thread.Sleep(Timeout.Infinite);
                }
            }
            catch (Exception topEx)
            {
                Log("FATAL TOP-LEVEL EXCEPTION: " + topEx);
                System.Windows.Forms.MessageBox.Show("Fatal error: " + topEx.Message, "OMPC Error", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
            }

            try { if (_httpListener != null) _httpListener.Stop(); } catch { }
            try { if (_tcpListener != null) _tcpListener.Stop(); } catch { }
        }

        private static void Log(string msg)
        {
            try
            {
                string debugLog = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "ompc_debug_log.txt");
                File.AppendAllText(debugLog, msg + "\r\n");
            }
            catch { }
        }

        private static void ListenLoop()
        {
            if (_httpListener != null)
            {
                while (_httpListener.IsListening)
                {
                    try
                    {
                        var ctx = _httpListener.GetContext();
                        ThreadPool.QueueUserWorkItem(ProcessHttpRequest, ctx);
                    }
                    catch { break; }
                }
            }
            else if (_tcpListener != null)
            {
                while (true)
                {
                    try
                    {
                        TcpClient client = _tcpListener.AcceptTcpClient();
                        ThreadPool.QueueUserWorkItem(ProcessTcpClient, client);
                    }
                    catch { break; }
                }
            }
        }

        private static void ProcessHttpRequest(object state)
        {
            var ctx = (HttpListenerContext)state;
            try
            {
                string rawUrl = ctx.Request.Url.AbsolutePath;
                if (rawUrl == "/" || string.IsNullOrEmpty(rawUrl)) rawUrl = "/index.html";
                string cleanPath = Uri.UnescapeDataString(rawUrl).TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                string fullPath = Path.Combine(_webRoot, cleanPath);
                if (!File.Exists(fullPath)) fullPath = Path.Combine(_webRoot, "index.html");

                if (File.Exists(fullPath))
                {
                    byte[] bytes = File.ReadAllBytes(fullPath);
                    ctx.Response.StatusCode = 200;
                    ctx.Response.ContentType = GetMimeType(Path.GetExtension(fullPath));
                    ctx.Response.ContentLength64 = bytes.Length;
                    ctx.Response.Headers.Add("Cache-Control", "no-cache");
                    ctx.Response.OutputStream.Write(bytes, 0, bytes.Length);
                }
                else
                {
                    ctx.Response.StatusCode = 404;
                }
            }
            catch { }
            finally
            {
                try { ctx.Response.OutputStream.Close(); } catch { }
            }
        }

        private static void ProcessTcpClient(object state)
        {
            TcpClient client = (TcpClient)state;
            try
            {
                client.ReceiveTimeout = 10000;
                client.SendTimeout = 60000;
                client.SendBufferSize = 64 * 1024;
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
                    if (rawUrl == "/" || string.IsNullOrEmpty(rawUrl)) rawUrl = "/index.html";

                    string cleanPath = Uri.UnescapeDataString(rawUrl).TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                    string fullPath = Path.Combine(_webRoot, cleanPath);
                    if (!File.Exists(fullPath)) fullPath = Path.Combine(_webRoot, "index.html");

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

                        // Stream bytes in 64KB chunks to prevent socket buffer congestion
                        int chunkSize = 64 * 1024;
                        int offset = 0;
                        while (offset < bytes.Length)
                        {
                            int count = Math.Min(chunkSize, bytes.Length - offset);
                            stream.Write(bytes, offset, count);
                            offset += count;
                        }
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

