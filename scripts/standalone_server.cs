using System;
using System.IO;
using System.Net;
using System.Diagnostics;
using System.Threading;

namespace OmpcBallisticAeroData
{
    class Program
    {
        private static HttpListener _listener;
        private static string _webRoot;
        private static int _port = 8080;
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

            // Terminate any old lingering instances
            try
            {
                int currentId = Process.GetCurrentProcess().Id;
                foreach (var proc in Process.GetProcessesByName("OMPC_Ballistic_AeroData"))
                {
                    if (proc.Id != currentId)
                    {
                        try { proc.Kill(); proc.WaitForExit(1000); } catch { }
                    }
                }
            }
            catch { }

            // Find an open port starting from 8080
            for (int p = 8080; p < 8180; p++)
            {
                try
                {
                    _listener = new HttpListener();
                    _listener.Prefixes.Add("http://127.0.0.1:" + p + "/");
                    try { _listener.Prefixes.Add("http://localhost:" + p + "/"); } catch { }
                    _listener.Start();
                    _port = p;
                    break;
                }
                catch
                {
                    if (_listener != null)
                    {
                        try { _listener.Close(); } catch { }
                        _listener = null;
                    }
                }
            }

            if (_listener == null || !_listener.IsListening)
            {
                System.Windows.Forms.MessageBox.Show(
                    "Could not bind local HTTP server port. Please check firewall or administrator privileges.",
                    "OMPC Ballistic AeroData - Server Error",
                    System.Windows.Forms.MessageBoxButtons.OK,
                    System.Windows.Forms.MessageBoxIcon.Error);
                return;
            }

            // Start listener thread
            Thread serverThread = new Thread(ListenLoop);
            serverThread.IsBackground = true;
            serverThread.Start();
            Thread.Sleep(150); // Ensure listener is ready to serve first request

            // Auto-update support: If connected to the internet, launch the live production web app directly
            // so every user automatically receives updates the instant they are published without stopping or reinstalling.
            // If offline, seamlessly fall back to the built-in embedded server.
            string appUrl = "http://127.0.0.1:" + _port + "/";
            try
            {
                HttpWebRequest onlineCheck = (HttpWebRequest)WebRequest.Create("https://ompc-ballistic-aerodata.web.app/");
                onlineCheck.Timeout = 1200;
                onlineCheck.Method = "HEAD";
                using (HttpWebResponse res = (HttpWebResponse)onlineCheck.GetResponse())
                {
                    if (res.StatusCode == HttpStatusCode.OK)
                    {
                        appUrl = "https://ompc-ballistic-aerodata.web.app/";
                    }
                }
            }
            catch { }
            string userDataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OMPC_Ballistic_AeroData", "browser_profile");
            try 
            { 
                Directory.CreateDirectory(userDataDir); 
                string firstRunFile = Path.Combine(userDataDir, "First Run");
                if (!File.Exists(firstRunFile))
                {
                    File.WriteAllText(firstRunFile, "");
                }
                string defaultDir = Path.Combine(userDataDir, "Default");
                Directory.CreateDirectory(defaultDir);
                string prefFile = Path.Combine(defaultDir, "Preferences");
                if (!File.Exists(prefFile))
                {
                    File.WriteAllText(prefFile, "{\"browser\":{\"has_seen_welcome_page\":true,\"check_default_browser\":false},\"profile\":{\"exit_type\":\"Normal\",\"exited_cleanly\":true}}");
                }
            } 
            catch { }

            string edgePath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                @"Microsoft\Edge\Application\msedge.exe");

            if (!File.Exists(edgePath))
            {
                edgePath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                    @"Microsoft\Edge\Application\msedge.exe");
            }

            string chromePath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                @"Google\Chrome\Application\chrome.exe");
            if (!File.Exists(chromePath))
            {
                chromePath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                    @"Google\Chrome\Application\chrome.exe");
            }

            string browserExe = File.Exists(edgePath) ? edgePath : (File.Exists(chromePath) ? chromePath : null);

            if (browserExe != null)
            {
                try
                {
                    string browserArgs = string.Format(
                        "--app={0} " +
                        "--user-data-dir=\"{1}\" " +
                        "--start-maximized " +
                        "--new-window " +
                        "--no-first-run " +
                        "--no-default-browser-check " +
                        "--disable-first-run-ui " +
                        "--disable-features=msEdgeSidebarV2,msHub,msHubEdgeShopping,Translate,OptimizationHints,MediaRouter " +
                        "--disable-extensions " +
                        "--disable-background-networking " +
                        "--disable-sync " +
                        "--disable-default-apps " +
                        "--app-id=OMPC_Ballistic_AeroData " +
                        "--class=OMPC_Ballistic_AeroData",
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
                    Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
                }
            }
            else
            {
                Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
            }

            // Keep server alive while app window is open
            // If the launcher process exits in under 4 seconds (e.g. delegated to existing instance), DO NOT exit! Keep server running indefinitely.
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

            try { _listener.Stop(); } catch { }
        }

        private static void ListenLoop()
        {
            while (_listener.IsListening)
            {
                try
                {
                    var ctx = _listener.GetContext();
                    ThreadPool.QueueUserWorkItem(ProcessRequest, ctx);
                }
                catch
                {
                    break;
                }
            }
        }

        private static void ProcessRequest(object state)
        {
            var ctx = (HttpListenerContext)state;
            try
            {
                string rawUrl = ctx.Request.Url.AbsolutePath;
                if (rawUrl == "/" || string.IsNullOrEmpty(rawUrl))
                {
                    rawUrl = "/index.html";
                }

                // Remove query strings / decodes
                string cleanPath = Uri.UnescapeDataString(rawUrl).TrimStart('/');
                cleanPath = cleanPath.Replace('/', Path.DirectorySeparatorChar);

                string fullPath = Path.Combine(_webRoot, cleanPath);

                // Default fallback to index.html for Single Page Applications (SPA)
                if (!File.Exists(fullPath))
                {
                    fullPath = Path.Combine(_webRoot, "index.html");
                }

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
            catch
            {
                ctx.Response.StatusCode = 500;
            }
            finally
            {
                try { ctx.Response.OutputStream.Close(); } catch { }
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
    }
}

