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

            if (!Directory.Exists(_webRoot))
            {
                // Also check if running directly inside build/web or alongside web files
                if (File.Exists(Path.Combine(baseDir, "index.html")))
                {
                    _webRoot = baseDir;
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

            // Find an open port starting from 8080
            for (int p = 8080; p < 8180; p++)
            {
                try
                {
                    _listener = new HttpListener();
                    _listener.Prefixes.Add("http://127.0.0.1:" + p + "/");
                    _listener.Prefixes.Add("http://localhost:" + p + "/");
                    _listener.Start();
                    _port = p;
                    break;
                }
                catch
                {
                    if (_listener != null)
                    {
                        try { _listener.Close(); } catch { }
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

            // Launch browser in dedicated app mode
            string appUrl = "http://localhost:" + _port + "/";
            string edgePath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                @"Microsoft\Edge\Application\msedge.exe");

            if (!File.Exists(edgePath))
            {
                edgePath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                    @"Microsoft\Edge\Application\msedge.exe");
            }

            try
            {
                if (File.Exists(edgePath))
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = edgePath,
                        Arguments = "--app=" + appUrl + " --window-size=1520,950",
                        UseShellExecute = true
                    };
                    _browserProcess = Process.Start(psi);
                }
                else
                {
                    Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
                }
            }
            catch (Exception ex)
            {
                Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
            }

            // Wait until process or application is closed
            if (_browserProcess != null)
            {
                try
                {
                    _browserProcess.WaitForExit();
                }
                catch { }
            }
            else
            {
                // Fallback: stay alive in background
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
                case ".ttf": return "font/ttf";
                case ".otf": return "font/otf";
                case ".woff": return "font/woff";
                case ".woff2": return "font/woff2";
                default: return "application/octet-stream";
            }
        }
    }
}
