using System;
using System.IO;
using System.Reflection;
using System.Diagnostics;
using System.Threading;
using System.Windows.Forms;
using System.Drawing;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using Microsoft.Win32;

namespace OmpcInstaller
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            if (args.Length > 0 && args[0].ToLower() == "/uninstall")
            {
                RunUninstall();
                return;
            }

            Application.Run(new InstallerForm());
        }

        static void RunUninstall()
        {
            DialogResult dr = MessageBox.Show(
                "Are you sure you want to completely uninstall OMPC Ballistic AeroData from this computer?",
                "OMPC Ballistic AeroData - Uninstall",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (dr != DialogResult.Yes) return;

            try
            {
                // Terminate any running instances
                foreach (var p in Process.GetProcessesByName("OMPC_Ballistic_AeroData"))
                {
                    try { p.Kill(); p.WaitForExit(1000); } catch { }
                }

                string localApp = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string installDir = Path.Combine(localApp, "Programs", "OMPC_Ballistic_AeroData");

                // Remove Desktop shortcut
                string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                string deskShortcut = Path.Combine(desktop, "OMPC Ballistic AeroData.lnk");
                if (File.Exists(deskShortcut)) { try { File.Delete(deskShortcut); } catch { } }

                // Remove Start Menu shortcut
                string startMenu = Environment.GetFolderPath(Environment.SpecialFolder.StartMenu);
                string startShortcut = Path.Combine(startMenu, "Programs", "OMPC Ballistic AeroData.lnk");
                if (File.Exists(startShortcut)) { try { File.Delete(startShortcut); } catch { } }

                // Remove Registry entry
                try
                {
                    Registry.CurrentUser.DeleteSubKeyTree(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\OMPC_Ballistic_AeroData", false);
                }
                catch { }

                // Clean files
                if (Directory.Exists(installDir))
                {
                    // Spawn a helper to delete the folder after uninstaller process exits
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = "cmd.exe",
                        Arguments = string.Format("/c ping 127.0.0.1 -n 2 > nul & rd /s /q \"{0}\"", installDir),
                        CreateNoWindow = true,
                        UseShellExecute = false
                    };
                    Process.Start(psi);
                }

                MessageBox.Show("OMPC Ballistic AeroData has been successfully uninstalled.", "Uninstall Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Error during uninstall: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    public class InstallerForm : Form
    {
        private ProgressBar _progressBar;
        private Label _statusLabel;
        private Button _installButton;
        private CheckBox _chkDesktop;
        private CheckBox _chkStartMenu;
        private CheckBox _chkLaunch;
        private TextBox _txtPath;

        public InstallerForm()
        {
            this.Text = "OMPC Ballistic AeroData Setup";
            this.Size = new Size(540, 420);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.BackColor = Color.FromArgb(248, 250, 252);
            this.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

            try
            {
                this.Icon = Icon.ExtractAssociatedIcon(Assembly.GetExecutingAssembly().Location);
            }
            catch { }

            // Header Panel
            Panel header = new Panel
            {
                Dock = DockStyle.Top,
                Height = 85,
                BackColor = Color.FromArgb(8, 27, 48)
            };

            PictureBox iconBox = new PictureBox
            {
                Size = new Size(48, 48),
                Location = new Point(20, 18),
                SizeMode = PictureBoxSizeMode.Zoom
            };
            try
            {
                if (this.Icon != null)
                {
                    iconBox.Image = this.Icon.ToBitmap();
                }
            }
            catch { }
            header.Controls.Add(iconBox);

            Label title = new Label
            {
                Text = "OMPC Ballistic AeroData",
                Font = new Font("Segoe UI", 14f, FontStyle.Bold),
                ForeColor = Color.White,
                Location = new Point(78, 16),
                AutoSize = true
            };

            Label subtitle = new Label
            {
                Text = "Quality Control & Ballistic Analysis Desktop System",
                Font = new Font("Segoe UI", 9.5f, FontStyle.Regular),
                ForeColor = Color.FromArgb(122, 165, 210),
                Location = new Point(80, 46),
                AutoSize = true
            };

            header.Controls.Add(title);
            header.Controls.Add(subtitle);
            this.Controls.Add(header);

            // Content
            int currentY = 105;

            Label lblDesc = new Label
            {
                Text = "Select your installation settings below, then click Install:",
                Location = new Point(24, currentY),
                AutoSize = true,
                ForeColor = Color.FromArgb(30, 41, 59)
            };
            this.Controls.Add(lblDesc);

            currentY += 30;
            Label lblDest = new Label
            {
                Text = "Installation Folder:",
                Location = new Point(24, currentY),
                AutoSize = true,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                ForeColor = Color.FromArgb(51, 65, 85)
            };
            this.Controls.Add(lblDest);

            currentY += 22;
            string defaultPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "OMPC_Ballistic_AeroData");

            _txtPath = new TextBox
            {
                Text = defaultPath,
                Location = new Point(24, currentY),
                Width = 475,
                ReadOnly = true,
                BackColor = Color.White
            };
            this.Controls.Add(_txtPath);

            currentY += 36;
            _chkDesktop = new CheckBox
            {
                Text = "Create a Desktop shortcut",
                Location = new Point(26, currentY),
                Checked = true,
                AutoSize = true,
                ForeColor = Color.FromArgb(30, 41, 59)
            };
            this.Controls.Add(_chkDesktop);

            currentY += 28;
            _chkStartMenu = new CheckBox
            {
                Text = "Add to Windows Start Menu",
                Location = new Point(26, currentY),
                Checked = true,
                AutoSize = true,
                ForeColor = Color.FromArgb(30, 41, 59)
            };
            this.Controls.Add(_chkStartMenu);

            currentY += 28;
            _chkLaunch = new CheckBox
            {
                Text = "Launch OMPC Ballistic AeroData after installation",
                Location = new Point(26, currentY),
                Checked = true,
                AutoSize = true,
                ForeColor = Color.FromArgb(30, 41, 59)
            };
            this.Controls.Add(_chkLaunch);

            currentY += 36;
            _progressBar = new ProgressBar
            {
                Location = new Point(24, currentY),
                Width = 475,
                Height = 18,
                Visible = false
            };
            this.Controls.Add(_progressBar);

            _statusLabel = new Label
            {
                Text = "",
                Location = new Point(24, currentY + 22),
                Width = 475,
                Height = 20,
                ForeColor = Color.FromArgb(100, 116, 139),
                Font = new Font("Segoe UI", 8.5f)
            };
            this.Controls.Add(_statusLabel);

            // Bottom Buttons
            _installButton = new Button
            {
                Text = "Install Application",
                Size = new Size(150, 36),
                Location = new Point(349, 325),
                BackColor = Color.FromArgb(8, 120, 200),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            _installButton.FlatAppearance.BorderSize = 0;
            _installButton.Click += InstallButton_Click;
            this.Controls.Add(_installButton);
        }

        private void InstallButton_Click(object sender, EventArgs e)
        {
            if (_installButton.Text == "Finish")
            {
                this.Close();
                return;
            }

            _installButton.Enabled = false;
            _chkDesktop.Enabled = false;
            _chkStartMenu.Enabled = false;
            _progressBar.Visible = true;
            _progressBar.Style = ProgressBarStyle.Marquee;
            _statusLabel.Text = "Preparing installation files...";

            string targetDir = _txtPath.Text;
            bool makeDesk = _chkDesktop.Checked;
            bool makeStart = _chkStartMenu.Checked;
            bool doLaunch = _chkLaunch.Checked;

            Thread worker = new Thread(new ThreadStart(delegate
            {
                try
                {
                    // Terminate any old instances first
                    foreach (var p in Process.GetProcessesByName("OMPC_Ballistic_AeroData"))
                    {
                        try { p.Kill(); p.WaitForExit(1000); } catch { }
                    }

                    if (!Directory.Exists(targetDir))
                    {
                        Directory.CreateDirectory(targetDir);
                    }

                    // Extract embedded payload zip resource
                    Assembly asm = Assembly.GetExecutingAssembly();
                    string resName = null;
                    foreach (string n in asm.GetManifestResourceNames())
                    {
                        if (n.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                        {
                            resName = n;
                            break;
                        }
                    }

                    if (string.IsNullOrEmpty(resName))
                    {
                        throw new Exception("Installation package resource not found.");
                    }

                    this.Invoke(new MethodInvoker(delegate { _statusLabel.Text = "Extracting application components..."; }));

                    string tempZip = Path.Combine(Path.GetTempPath(), "ompc_setup_" + Guid.NewGuid().ToString("N") + ".zip");
                    using (Stream s = asm.GetManifestResourceStream(resName))
                    using (FileStream fs = new FileStream(tempZip, FileMode.Create, FileAccess.Write))
                    {
                        s.CopyTo(fs);
                    }

                    // Extract to targetDir
                    ZipFile.ExtractToDirectory(tempZip, targetDir);
                    try { File.Delete(tempZip); } catch { }

                    string targetExe = Path.Combine(targetDir, "OMPC_Ballistic_AeroData.exe");
                    if (!File.Exists(targetExe))
                    {
                        // Check if inside build or subfolder
                        string subExe = Path.Combine(targetDir, "build", "OMPC_Ballistic_AeroData.exe");
                        if (File.Exists(subExe))
                        {
                            targetExe = subExe;
                        }
                    }

                    // Copy installer itself as uninstaller
                    string uninstallerPath = Path.Combine(targetDir, "Uninstall.exe");
                    try
                    {
                        File.Copy(Assembly.GetExecutingAssembly().Location, uninstallerPath, true);
                    }
                    catch { }

                    this.Invoke(new MethodInvoker(delegate { _statusLabel.Text = "Creating shortcuts and registering application..."; }));

                    // Create Shortcuts
                    if (makeDesk)
                    {
                        string deskDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                        CreateShortcut(Path.Combine(deskDir, "OMPC Ballistic AeroData.lnk"), targetExe, "OMPC Ballistic AeroData System");
                    }

                    if (makeStart)
                    {
                        string startDir = Environment.GetFolderPath(Environment.SpecialFolder.StartMenu);
                        string progDir = Path.Combine(startDir, "Programs");
                        Directory.CreateDirectory(progDir);
                        CreateShortcut(Path.Combine(progDir, "OMPC Ballistic AeroData.lnk"), targetExe, "OMPC Ballistic AeroData System");
                    }

                    // Register in Windows Registry for Add/Remove Programs
                    try
                    {
                        using (RegistryKey key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\OMPC_Ballistic_AeroData"))
                        {
                            if (key != null)
                            {
                                key.SetValue("DisplayName", "OMPC Ballistic AeroData");
                                key.SetValue("DisplayIcon", targetExe);
                                key.SetValue("DisplayVersion", "1.0.0");
                                key.SetValue("Publisher", "OMPC");
                                key.SetValue("InstallLocation", targetDir);
                                key.SetValue("UninstallString", "\"" + uninstallerPath + "\" /uninstall");
                            }
                        }
                    }
                    catch { }

                    this.Invoke(new MethodInvoker(delegate
                    {
                        _progressBar.Style = ProgressBarStyle.Continuous;
                        _progressBar.Value = 100;
                        _statusLabel.Text = "Installation completed successfully!";
                        _statusLabel.ForeColor = Color.FromArgb(16, 149, 193);
                        _installButton.Text = "Finish";
                        _installButton.Enabled = true;

                        if (doLaunch && File.Exists(targetExe))
                        {
                            try
                            {
                                Process.Start(new ProcessStartInfo
                                {
                                    FileName = targetExe,
                                    WorkingDirectory = Path.GetDirectoryName(targetExe)
                                });
                            }
                            catch { }
                        }
                    }));
                }
                catch (Exception ex)
                {
                    this.Invoke(new MethodInvoker(delegate
                    {
                        _progressBar.Visible = false;
                        _statusLabel.Text = "Installation failed: " + ex.Message;
                        _statusLabel.ForeColor = Color.Red;
                        _installButton.Enabled = true;
                        _installButton.Text = "Retry";
                    }));
                }
            }));

            worker.IsBackground = true;
            worker.Start();
        }

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

        [ComImport, Guid("00021401-0000-0000-C000-000000000046"), ClassInterface(ClassInterfaceType.None)]
        public class ShellLink { }

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

        private static void SetAumidOnShortcut(string shortcutPath, string aumid, string targetExe)
        {
            try
            {
                ShellLink link = new ShellLink();
                IPersistFile persistFile = (IPersistFile)link;
                // STGM_READWRITE = 2
                persistFile.Load(shortcutPath, 2);

                IPropertyStore store = (IPropertyStore)link;
                SetProp(store, PKEY_AppUserModel_ID, aumid);
                SetProp(store, PKEY_AppUserModel_RelaunchCommand, targetExe);
                SetProp(store, PKEY_AppUserModel_RelaunchDisplayNameResource, "OMPC Ballistic AeroData");
                SetProp(store, PKEY_AppUserModel_RelaunchIconResource, targetExe + ",0");
                store.Commit();

                persistFile.Save(shortcutPath, true);
                Marshal.ReleaseComObject(store);
                Marshal.ReleaseComObject(link);
            }
            catch { }
        }

        private static void CreateShortcut(string shortcutPath, string targetExePath, string description)
        {
            try
            {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType == null) return;
                object shell = Activator.CreateInstance(shellType);
                object shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { shortcutPath });
                Type scType = shortcut.GetType();
                scType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { targetExePath });
                scType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { Path.GetDirectoryName(targetExePath) });

                string iconIco = Path.Combine(Path.GetDirectoryName(targetExePath), "app_icon.ico");
                if (File.Exists(iconIco))
                {
                    scType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { iconIco + ",0" });
                }
                else
                {
                    scType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { targetExePath + ",0" });
                }

                scType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { description });
                scType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);

                SetAumidOnShortcut(shortcutPath, "OMPC.Ballistic.AeroData", targetExePath);
            }
            catch { }
        }
    }
}
