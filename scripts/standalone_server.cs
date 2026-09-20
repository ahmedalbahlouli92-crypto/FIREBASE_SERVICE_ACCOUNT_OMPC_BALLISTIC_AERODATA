using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Windows.Forms;
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
        private static IntPtr _browserHwnd = IntPtr.Zero;

        private const string AppId = "OMPC.Ballistic.AeroData";

        #region Win32 Shell & Window APIs for Taskbar Grouping
        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        public struct PROPERTYKEY
        {
            public Guid fmtid;
            public uint pid;
        }

        [StructLayout(LayoutKind.Explicit)]
        public struct PROPVARIANT
        {
            [FieldOffset(0)] public ushort vt;
            [FieldOffset(8)] public IntPtr pwszVal;
        }

        [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        public interface IPropertyStore
        {
            [PreserveSig] int GetCount(out uint cProps);
            [PreserveSig] int GetAt(uint iProp, out PROPERTYKEY pkey);
            [PreserveSig] int GetValue([In] ref PROPERTYKEY key, out PROPVARIANT pv);
            [PreserveSig] int SetValue([In] ref PROPERTYKEY key, [In] ref PROPVARIANT pv);
            [PreserveSig] int Commit();
        }

        [DllImport("shell32.dll", SetLastError = true)]
        public static extern int SHGetPropertyStoreForWindow(IntPtr handle, ref Guid riid, out IPropertyStore propertyStore);

        [DllImport("shell32.dll", SetLastError = true)]
        public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        public static readonly PROPERTYKEY PKEY_AppUserModel_ID = new PROPERTYKEY
        {
            fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5
        };
        public static readonly PROPERTYKEY PKEY_AppUserModel_RelaunchCommand = new PROPERTYKEY
        {
            fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 2
        };
        public static readonly PROPERTYKEY PKEY_AppUserModel_RelaunchDisplayNameResource = new PROPERTYKEY
        {
            fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 4
        };
        public static readonly PROPERTYKEY PKEY_AppUserModel_RelaunchIconResource = new PROPERTYKEY
        {
            fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 3
        };

        private static bool ApplyAumidToWindow(IntPtr hwnd, string aumid, string exePath, string displayName)
        {
            try
            {
                Guid guid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
                IPropertyStore store;
                int hr = SHGetPropertyStoreForWindow(hwnd, ref guid, out store);
                if (hr != 0 || store == null) return false;

                try
                {
                    SetProp(store, PKEY_AppUserModel_RelaunchCommand, exePath);
                    SetProp(store, PKEY_AppUserModel_RelaunchDisplayNameResource, displayName);
                    SetProp(store, PKEY_AppUserModel_RelaunchIconResource, exePath + ",0");
                    SetProp(store, PKEY_AppUserModel_ID, aumid);
                    store.Commit();
                    return true;
                }
                finally
                {
                    Marshal.ReleaseComObject(store);
                }
            }
            catch { return false; }
        }

        private static void SetProp(IPropertyStore store, PROPERTYKEY key, string value)
        {
            PROPVARIANT pv = new PROPVARIANT();
            pv.vt = 31; // VT_LPWSTR
            pv.pwszVal = Marshal.StringToCoTaskMemUni(value);
            try
            {
                store.SetValue(ref key, ref pv);
            }
            finally
            {
                Marshal.FreeCoTaskMem(pv.pwszVal);
            }
        }

        private static IntPtr FindBrowserWindow(int targetPid)
        {
            IntPtr foundHwnd = IntPtr.Zero;
            EnumWindows((hwnd, lparam) =>
            {
                if (!IsWindowVisible(hwnd)) return true;

                StringBuilder cls = new StringBuilder(256);
                GetClassName(hwnd, cls, cls.Capacity);
                if (cls.ToString() == "Chrome_WidgetWin_1")
                {
                    uint winPid;
                    GetWindowThreadProcessId(hwnd, out winPid);
                    StringBuilder title = new StringBuilder(256);
                    GetWindowText(hwnd, title, title.Capacity);
                    string t = title.ToString();

                    if ((targetPid > 0 && winPid == targetPid) ||
                        t.IndexOf("OMPC", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        t.IndexOf("Ballistic", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        t.IndexOf("127.0.0.1", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        foundHwnd = hwnd;
                        return false;
                    }
                }
                return true;
            }, IntPtr.Zero);
            return foundHwnd;
        }

        public static bool IsPortAvailable(int port)
        {
            TcpListener tcp = null;
            try
            {
                tcp = new TcpListener(IPAddress.Loopback, port);
                tcp.ExclusiveAddressUse = true;
                tcp.Start();
                tcp.Stop();
                return true;
            }
            catch
            {
                return false;
            }
            finally
            {
                if (tcp != null)
                {
                    try { tcp.Stop(); } catch { }
                }
            }
        }
        #endregion

        #region App Host Form (Prevents Duplicate Taskbar Icon)
        public class AppHostForm : Form
        {
            [DllImport("user32.dll")] public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
            [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
            [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
            [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
            [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);

            private const int GWL_STYLE = -16;
            private const int WS_VISIBLE = 0x10000000;
            private const int WS_CHILD = 0x40000000;
            private const int WS_POPUP = unchecked((int)0x80000000);
            private const int WS_CAPTION = 0x00C00000;
            private const int WS_THICKFRAME = 0x00040000;

            private Process _childProc;
            private IntPtr _childHwnd = IntPtr.Zero;
            private string _profileDir;
            private Label _loadingLabel;
            private bool _embedded = false;

            public AppHostForm(string appUrl, string profileDir, string browserExe, string currentExe)
            {
                this.Text = "OMPC Ballistic AeroData";
                this.Size = new Size(1280, 800);
                this.StartPosition = FormStartPosition.CenterScreen;
                this.WindowState = FormWindowState.Maximized;
                this.BackColor = Color.FromArgb(11, 15, 25); // OMPC dark theme background

                _profileDir = profileDir;

                // Load custom application icon
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string iconPath = Path.Combine(baseDir, "app_icon.ico");
                if (!File.Exists(iconPath))
                    iconPath = Path.Combine(baseDir, "windows", "runner", "resources", "app_icon.ico");
                if (File.Exists(iconPath))
                {
                    try { this.Icon = new Icon(iconPath); } catch { }
                }
                else
                {
                    try { this.Icon = Icon.ExtractAssociatedIcon(currentExe); } catch { }
                }

                _loadingLabel = new Label
                {
                    Text = "Starting OMPC Ballistic AeroData...",
                    ForeColor = Color.FromArgb(16, 149, 193),
                    Font = new Font("Segoe UI", 16, FontStyle.Bold),
                    AutoSize = false,
                    TextAlign = ContentAlignment.MiddleCenter,
                    Dock = DockStyle.Fill
                };
                this.Controls.Add(_loadingLabel);

                // Launch browser process
                try
                {
                    string browserArgs = string.Format(
                        "--app=\"{0}\" --start-maximized --user-data-dir=\"{1}\" --no-first-run --no-default-browser-check",
                        appUrl, profileDir);

                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = browserExe,
                        Arguments = browserArgs,
                        UseShellExecute = true
                    };
                    Program.Log("Launching browser from host form: " + browserExe + " " + browserArgs);
                    _childProc = Process.Start(psi);
                    _browserProcess = _childProc;
                }
                catch (Exception ex)
                {
                    Program.Log("Error starting browser process: " + ex);
                }

                // Background Thread: Locate browser window and embed into this Form
                Thread embedThread = new Thread(() =>
                {
                    for (int i = 0; i < 60; i++)
                    {
                        Thread.Sleep(100);
                        if (_childProc != null && !_childProc.HasExited)
                        {
                            IntPtr found = FindBrowserWindow(_childProc.Id);
                            if (found != IntPtr.Zero)
                            {
                                _childHwnd = found;
                                _browserHwnd = found;
                                break;
                            }
                        }
                    }

                    if (_childHwnd != IntPtr.Zero)
                    {
                        try
                        {
                            this.BeginInvoke(new MethodInvoker(() =>
                            {
                                try
                                {
                                    SetParent(_childHwnd, this.Handle);
                                    int style = GetWindowLong(_childHwnd, GWL_STYLE);
                                    style = (style & ~WS_POPUP & ~WS_CAPTION & ~WS_THICKFRAME) | WS_CHILD | WS_VISIBLE;
                                    SetWindowLong(_childHwnd, GWL_STYLE, style);
                                    ResizeChild();
                                    SetForegroundWindow(_childHwnd);
                                    _loadingLabel.Visible = false;
                                    _embedded = true;
                                    Program.Log("Browser window embedded into host Form successfully.");
                                }
                                catch (Exception ex)
                                {
                                    Program.Log("Exception embedding browser: " + ex);
                                }
                            }));
                        }
                        catch { }
                    }
                    else
                    {
                        Program.Log("Browser window embedding timed out; continuing in dual mode.");
                    }
                });
                embedThread.IsBackground = true;
                embedThread.Start();

                this.Resize += (s, e) => ResizeChild();

                this.FormClosed += (s, e) =>
                {
                    Program.Log("AppHostForm closed. Exiting application.");
                    try { if (_childProc != null && !_childProc.HasExited) _childProc.Kill(); } catch { }
                    try
                    {
                        if (Directory.Exists(_profileDir))
                            Directory.Delete(_profileDir, true);
                    }
                    catch { }
                };
            }

            private void ResizeChild()
            {
                if (_childHwnd != IntPtr.Zero && _embedded)
                {
                    MoveWindow(_childHwnd, 0, 0, this.ClientSize.Width, this.ClientSize.Height, true);
                }
            }
        }
        #endregion

        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                try { SetCurrentProcessExplicitAppUserModelID(AppId); } catch { }
                string currentExe = Process.GetCurrentProcess().MainModule.FileName;

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

                // Port Selection with Strict Availability Check (allows multiple concurrent users/instances)
                for (int p = 8080; p < 8200; p++)
                {
                    if (!IsPortAvailable(p)) continue;
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

                // Fallback TcpListener if HttpListener failed
                if (_httpListener == null || !_httpListener.IsListening)
                {
                    for (int p = 8080; p < 8200; p++)
                    {
                        if (!IsPortAvailable(p)) continue;
                        try
                        {
                            _tcpListener = new TcpListener(IPAddress.Loopback, p);
                            _tcpListener.ExclusiveAddressUse = true;
                            _tcpListener.Start();
                            _port = p;
                            Log("TcpListener fallback bound to port: " + _port);
                            break;
                        }
                        catch
                        {
                            if (_tcpListener != null)
                            {
                                try { _tcpListener.Stop(); } catch { }
                                _tcpListener = null;
                            }
                        }
                    }

                    if (_tcpListener == null)
                    {
                        Log("All port bindings failed!");
                        System.Windows.Forms.MessageBox.Show(
                            "Could not find an available local port for the OMPC server.",
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

                // Multi-User Isolated Session: Assign dedicated profile folder per port
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string userProfileDir = Path.Combine(localAppData, "OMPC_Ballistic_AeroData", "profiles", "session_" + _port);
                try { Directory.CreateDirectory(userProfileDir); } catch { }

                // Launch local application URL
                string appUrl = "http://127.0.0.1:" + _port + "/";
                Log("App URL: " + appUrl);

                string browserExe = FindChromiumBrowser();
                Log("Found browserExe: " + (browserExe ?? "NULL"));

                if (browserExe != null)
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    Application.Run(new AppHostForm(appUrl, userProfileDir, browserExe, currentExe));
                }
                else
                {
                    Log("No browserExe found, opening default system browser");
                    Process.Start(new ProcessStartInfo { FileName = appUrl, UseShellExecute = true });
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

