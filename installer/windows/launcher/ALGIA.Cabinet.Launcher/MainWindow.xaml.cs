using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media.Imaging;
using Forms = System.Windows.Forms;

namespace ALGIA.Cabinet.Launcher
{
    public partial class MainWindow : Window
    {
        private string PackageDir { get; set; }
        private string RootDir { get; set; }

        private sealed class BackupChoice
        {
            public string Display { get; set; } = "";
            public string Path { get; set; } = "";

            public override string ToString()
            {
                return Display;
            }
        }

        public MainWindow()
        {
            InitializeComponent();

            LoadHeaderLogoSafe();

            PackageDir = FindPackageDirectory();
            RootDir = LoadSavedRootDir();

            RefreshInstallDisplay();
            AppendLog("ALGIA Cabinet Launcher initialisé.");
            AppendLog("Package : " + PackageDir);
            AppendLog("Dossier d’installation : " + RootDir);
        }

        private void LoadHeaderLogoSafe()
        {
            try
            {
                var baseDir = AppContext.BaseDirectory;

                var candidates = new[]
                {
                    Path.Combine(baseDir, "algia-cabinet-desktop.png"),
                    Path.Combine(baseDir, "assets", "algia-cabinet-desktop.png"),
                    Path.Combine(Directory.GetCurrentDirectory(), "assets", "algia-cabinet-desktop.png"),
                    Path.Combine(Directory.GetCurrentDirectory(), "installer", "windows", "assets", "algia-cabinet-desktop.png")
                };

                foreach (var path in candidates)
                {
                    if (!File.Exists(path))
                        continue;

                    var bitmap = new BitmapImage();
                    bitmap.BeginInit();
                    bitmap.CacheOption = BitmapCacheOption.OnLoad;
                    bitmap.UriSource = new Uri(path, UriKind.Absolute);
                    bitmap.EndInit();
                    bitmap.Freeze();

                    HeaderLogoImage.Source = bitmap;
                    return;
                }
            }
            catch
            {
                // Ne jamais bloquer le launcher pour un logo.
            }
        }

        private string StateDirectory()
        {
            var dir = Path.Combine(PackageDir, "state");
            Directory.CreateDirectory(dir);
            return dir;
        }

        private string SavedRootPathFile()
        {
            return Path.Combine(StateDirectory(), "install-root.txt");
        }

        private string LoadSavedRootDir()
        {
            try
            {
                var file = SavedRootPathFile();

                if (File.Exists(file))
                {
                    var saved = File.ReadAllText(file).Trim();

                    if (!string.IsNullOrWhiteSpace(saved) && Directory.Exists(saved))
                    {
                        return saved;
                    }
                }
            }
            catch
            {
                // Ne jamais bloquer le launcher pour une préférence locale.
            }

            return PackageDir;
        }

        private void SaveRootDirPreference()
        {
            try
            {
                File.WriteAllText(SavedRootPathFile(), RootDir);
                AppendLog("Dossier mémorisé : " + RootDir);
            }
            catch (Exception ex)
            {
                AppendLog("Impossible de mémoriser le dossier : " + ex.Message);
            }
        }

        private string FindPackageDirectory()
        {
            var dir = AppContext.BaseDirectory;

            while (!string.IsNullOrWhiteSpace(dir))
            {
                if (File.Exists(Path.Combine(dir, "docker-compose.yml")) &&
                    Directory.Exists(Path.Combine(dir, "installer", "windows", "scripts")))
                {
                    return dir;
                }

                var parent = Directory.GetParent(dir);
                if (parent == null)
                    break;

                dir = parent.FullName;
            }

            return Directory.GetCurrentDirectory();
        }

        private void RefreshInstallDisplay()
        {
            RootText.Text = RootDir;
            InstallFolderText.Text = RootDir;
            LoadAdminPasswordFromEnv();
        }

        private void LoadAdminPasswordFromEnv()
        {
            var envPath = Path.Combine(RootDir, ".env");

            if (!File.Exists(envPath))
            {
                AdminPasswordText.Text = "Mot de passe temporaire : non créé";
                return;
            }

            foreach (var line in File.ReadAllLines(envPath))
            {
                if (line.StartsWith("ADMIN_PASSWORD=", StringComparison.OrdinalIgnoreCase))
                {
                    var password = line.Substring("ADMIN_PASSWORD=".Length).Trim();
                    AdminPasswordText.Text = "Mot de passe temporaire : " + password;
                    return;
                }
            }

            AdminPasswordText.Text = "Mot de passe temporaire : non trouvé";
        }

        private void AppendLog(string text)
        {
            LogBox.AppendText($"[{DateTime.Now:HH:mm:ss}] {text}{Environment.NewLine}");
            LogBox.ScrollToEnd();
        }

        private void SetStatus(string text)
        {
            StatusText.Text = text;
            AppendLog(text);
        }

        private bool IsSamePath(string a, string b)
        {
            return string.Equals(
                Path.GetFullPath(a).TrimEnd('\\'),
                Path.GetFullPath(b).TrimEnd('\\'),
                StringComparison.OrdinalIgnoreCase
            );
        }

        private string QuoteArg(string value)
        {
            return "\"" + value.Replace("\"", "\\\"") + "\"";
        }

        private void CopyFileIfExists(string sourceRelative, string destinationRelative, bool overwrite = true)
        {
            var src = Path.Combine(PackageDir, sourceRelative);
            var dst = Path.Combine(RootDir, destinationRelative);

            if (!File.Exists(src))
            {
                AppendLog("Fichier source absent : " + src);
                return;
            }

            if (IsSamePath(src, dst))
                return;

            var dstDir = Path.GetDirectoryName(dst);
            if (!string.IsNullOrWhiteSpace(dstDir))
                Directory.CreateDirectory(dstDir);

            if (File.Exists(dst) && !overwrite)
                return;

            File.Copy(src, dst, overwrite);
        }

        private void CopyDirectory(string sourceRelative, string destinationRelative)
        {
            var srcRoot = Path.Combine(PackageDir, sourceRelative);
            var dstRoot = Path.Combine(RootDir, destinationRelative);

            if (!Directory.Exists(srcRoot))
            {
                AppendLog("Dossier source absent : " + srcRoot);
                return;
            }

            if (IsSamePath(srcRoot, dstRoot))
                return;

            Directory.CreateDirectory(dstRoot);

            foreach (var dir in Directory.GetDirectories(srcRoot, "*", SearchOption.AllDirectories))
            {
                var rel = Path.GetRelativePath(srcRoot, dir);
                Directory.CreateDirectory(Path.Combine(dstRoot, rel));
            }

            foreach (var file in Directory.GetFiles(srcRoot, "*", SearchOption.AllDirectories))
            {
                var rel = Path.GetRelativePath(srcRoot, file);
                var dst = Path.Combine(dstRoot, rel);
                var parent = Path.GetDirectoryName(dst);

                if (!string.IsNullOrWhiteSpace(parent))
                    Directory.CreateDirectory(parent);

                File.Copy(file, dst, true);
            }
        }

        private void PrepareSelectedFolder()
        {
            Directory.CreateDirectory(RootDir);

            CopyFileIfExists(".env.example", ".env.example");
            CopyFileIfExists("docker-compose.yml", "docker-compose.yml");
            CopyFileIfExists("README.md", "README.md");

            CopyFileIfExists("INSTALLER-ALGIA-CABINET.bat", "INSTALLER-ALGIA-CABINET.bat");
            CopyFileIfExists("DEMARRER-ALGIA-CABINET.bat", "DEMARRER-ALGIA-CABINET.bat");
            CopyFileIfExists("ARRETER-ALGIA-CABINET.bat", "ARRETER-ALGIA-CABINET.bat");
            CopyFileIfExists("SAUVEGARDE-ALGIA-CABINET.bat", "SAUVEGARDE-ALGIA-CABINET.bat");
            CopyFileIfExists("METTRE-A-JOUR-ALGIA-CABINET.bat", "METTRE-A-JOUR-ALGIA-CABINET.bat");
            CopyFileIfExists("RESTAURER-ALGIA-CABINET.bat", "RESTAURER-ALGIA-CABINET.bat");

            CopyDirectory("bootstrap", "bootstrap");
            CopyDirectory("manifests", "manifests");
            CopyDirectory("docs", "docs");
            CopyDirectory(Path.Combine("installer", "windows", "scripts"), Path.Combine("installer", "windows", "scripts"));

            Directory.CreateDirectory(Path.Combine(RootDir, "backups"));
            Directory.CreateDirectory(Path.Combine(RootDir, "logs"));
            Directory.CreateDirectory(Path.Combine(RootDir, "state"));
            Directory.CreateDirectory(Path.Combine(RootDir, "releases"));

            SaveRootDirPreference();
            RefreshInstallDisplay();
        }

        private async Task<int> RunCommandAsync(string command)
        {
            return await RunProcessAsync("cmd.exe", "/c " + command);
        }

        private async Task<int> RunProcessAsync(string fileName, string arguments)
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = fileName,
                    Arguments = arguments,
                    WorkingDirectory = RootDir,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };

                using var process = new Process();
                process.StartInfo = psi;
                process.EnableRaisingEvents = true;

                process.OutputDataReceived += (_, e) =>
                {
                    if (e.Data != null)
                        Dispatcher.Invoke(() => AppendLog(e.Data));
                };

                process.ErrorDataReceived += (_, e) =>
                {
                    if (e.Data != null)
                        Dispatcher.Invoke(() => AppendLog(e.Data));
                };

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                await process.WaitForExitAsync();

                return process.ExitCode;
            }
            catch (Exception ex)
            {
                AppendLog("Erreur : " + ex.Message);
                return 1;
            }
        }

        private async Task RunPowerShellScriptInlineAsync(string relativeScript, string extraArguments = "")
        {
            PrepareSelectedFolder();

            var scriptPath = Path.Combine(RootDir, relativeScript);

            if (!File.Exists(scriptPath))
            {
                AppendLog("Script introuvable : " + scriptPath);
                MessageBox.Show("Script introuvable :\n" + scriptPath, "ALGIA Cabinet Launcher", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            SetStatus("Exécution : " + Path.GetFileName(scriptPath));

            var args = "-NoProfile -ExecutionPolicy Bypass -File " + QuoteArg(scriptPath);

            if (!string.IsNullOrWhiteSpace(extraArguments))
                args += " " + extraArguments;

            var code = await RunProcessAsync("powershell.exe", args);

            RefreshInstallDisplay();

            if (code == 0)
                SetStatus("Terminé : " + Path.GetFileName(scriptPath));
            else
                SetStatus("Erreur : " + Path.GetFileName(scriptPath) + " code " + code);
        }

        private async void CheckMachine_Click(object sender, RoutedEventArgs e)
        {
            SetStatus("Vérification machine...");

            AppendLog("Test docker --version");
            var dockerCode = await RunCommandAsync("docker --version");
            DockerText.Text = dockerCode == 0 ? "OK" : "Absent";

            AppendLog("Test docker compose version");
            var composeCode = await RunCommandAsync("docker compose version");
            ComposeText.Text = composeCode == 0 ? "OK" : "Absent";

            AppendLog("Test docker info");
            var infoCode = await RunCommandAsync("docker info");

            if (infoCode == 0)
                AppendLog("Docker daemon démarré.");
            else
                AppendLog("Docker daemon non disponible. Lance Docker Desktop.");

            if (File.Exists(Path.Combine(RootDir, ".env")))
                AppendLog(".env présent.");
            else
                AppendLog(".env absent, il sera créé à l'installation.");

            RefreshInstallDisplay();
            SetStatus("Vérification terminée");
        }

        private void ChooseFolder_Click(object sender, RoutedEventArgs e)
        {
            using var dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choisir le dossier d'installation ALGIA Cabinet";
            dialog.SelectedPath = RootDir;
            dialog.ShowNewFolderButton = true;

            if (dialog.ShowDialog() == Forms.DialogResult.OK)
            {
                RootDir = dialog.SelectedPath;
                SaveRootDirPreference();
                RefreshInstallDisplay();
                AppendLog("Dossier d’installation sélectionné : " + RootDir);

                try
                {
                    PrepareSelectedFolder();
                    AppendLog("Le dossier sélectionné est prêt.");
                }
                catch (Exception ex)
                {
                    AppendLog("Erreur préparation dossier : " + ex.Message);
                    MessageBox.Show("Erreur préparation dossier :\n" + ex.Message, "ALGIA Cabinet Launcher", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private string? ChooseBackupFolder()
        {
            var backupsRoot = Path.Combine(RootDir, "backups");

            if (!Directory.Exists(backupsRoot))
            {
                MessageBox.Show(
                    "Aucun dossier de sauvegarde trouvé :\n" + backupsRoot,
                    "Restauration ALGIA Cabinet",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information
                );
                return null;
            }

            var dirs = Directory.GetDirectories(backupsRoot)
                .Select(d => new DirectoryInfo(d))
                .OrderByDescending(d => d.LastWriteTime)
                .ToArray();

            if (dirs.Length == 0)
            {
                MessageBox.Show(
                    "Aucune sauvegarde disponible dans :\n" + backupsRoot,
                    "Restauration ALGIA Cabinet",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information
                );
                return null;
            }

            using var form = new Forms.Form();
            form.Text = "Choisir une sauvegarde ALGIA Cabinet";
            form.Width = 860;
            form.Height = 460;
            form.StartPosition = Forms.FormStartPosition.CenterScreen;
            form.FormBorderStyle = Forms.FormBorderStyle.FixedDialog;
            form.MaximizeBox = false;
            form.MinimizeBox = false;

            var title = new Forms.Label
            {
                Left = 20,
                Top = 18,
                Width = 800,
                Height = 28,
                Text = "Sélectionnez la sauvegarde à restaurer",
                Font = new System.Drawing.Font("Segoe UI", 12, System.Drawing.FontStyle.Bold)
            };
            form.Controls.Add(title);

            var hint = new Forms.Label
            {
                Left = 20,
                Top = 48,
                Width = 800,
                Height = 24,
                Text = "Les sauvegardes sont triées de la plus récente à la plus ancienne.",
                Font = new System.Drawing.Font("Segoe UI", 9)
            };
            form.Controls.Add(hint);

            var list = new Forms.ListBox
            {
                Left = 20,
                Top = 82,
                Width = 800,
                Height = 270,
                Font = new System.Drawing.Font("Consolas", 10)
            };

            foreach (var dir in dirs)
            {
                var dbCount = Directory.GetFiles(dir.FullName, "*database.sql.gz", SearchOption.TopDirectoryOnly).Length;
                var filesCount = Directory.GetFiles(dir.FullName, "*files.tar", SearchOption.TopDirectoryOnly).Length;
                var privateCount = Directory.GetFiles(dir.FullName, "*private-files.tar", SearchOption.TopDirectoryOnly).Length;

                var label = $"{dir.LastWriteTime:dd/MM/yyyy HH:mm:ss}   |   {dir.Name}   |   DB:{dbCount} PUBLIC:{filesCount} PRIVATE:{privateCount}";

                list.Items.Add(new BackupChoice
                {
                    Display = label,
                    Path = dir.FullName
                });
            }

            list.SelectedIndex = 0;
            form.Controls.Add(list);

            var cancel = new Forms.Button
            {
                Text = "Annuler",
                Left = 410,
                Top = 370,
                Width = 130,
                Height = 34,
                DialogResult = Forms.DialogResult.Cancel
            };
            form.Controls.Add(cancel);

            var ok = new Forms.Button
            {
                Text = "Restaurer cette sauvegarde",
                Left = 560,
                Top = 370,
                Width = 220,
                Height = 34,
                DialogResult = Forms.DialogResult.OK
            };
            form.Controls.Add(ok);

            form.AcceptButton = ok;
            form.CancelButton = cancel;

            var result = form.ShowDialog();

            if (result != Forms.DialogResult.OK)
                return null;

            if (list.SelectedItem is BackupChoice choice)
                return choice.Path;

            return null;
        }

        private bool IsInstalled()
        {
            return File.Exists(Path.Combine(RootDir, ".env")) &&
                   File.Exists(Path.Combine(RootDir, "docker-compose.yml"));
        }

        private async void InstallOrStart_Click(object sender, RoutedEventArgs e)
        {
            if (IsInstalled())
            {
                AppendLog("Installation détectée. Démarrage ALGIA Cabinet...");
                await RunPowerShellScriptInlineAsync(@"installer\windows\scripts\start.ps1");
                return;
            }

            AppendLog("Première installation détectée. Installation puis lancement ALGIA Cabinet...");
            await RunPowerShellScriptInlineAsync(
                @"installer\windows\scripts\install.ps1",
                "-SourceDir " + QuoteArg(PackageDir)
            );
        }

        private async void Install_Click(object sender, RoutedEventArgs e)
        {
            await RunPowerShellScriptInlineAsync(
                @"installer\windows\scripts\install.ps1",
                "-SourceDir " + QuoteArg(PackageDir)
            );
        }

        private async void Start_Click(object sender, RoutedEventArgs e)
        {
            await RunPowerShellScriptInlineAsync(@"installer\windows\scripts\start.ps1");
        }

        private async void Stop_Click(object sender, RoutedEventArgs e)
        {
            await RunPowerShellScriptInlineAsync(@"installer\windows\scripts\stop.ps1");
        }

        private async void Backup_Click(object sender, RoutedEventArgs e)
        {
            await RunPowerShellScriptInlineAsync(@"installer\windows\scripts\backup.ps1");
        }

        private async void Restore_Click(object sender, RoutedEventArgs e)
        {
            var backupDir = ChooseBackupFolder();

            if (string.IsNullOrWhiteSpace(backupDir))
            {
                AppendLog("Restauration annulée.");
                return;
            }

            AppendLog("Sauvegarde choisie : " + backupDir);

            var confirm = MessageBox.Show(
                "Restaurer cette sauvegarde ?\n\n" + backupDir + "\n\nCette action remplace les données actuelles.",
                "Confirmation restauration",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning
            );

            if (confirm != MessageBoxResult.Yes)
            {
                AppendLog("Restauration annulée par l’utilisateur.");
                return;
            }

            await RunPowerShellScriptInlineAsync(
                @"installer\windows\scripts\restore.ps1",
                "-BackupDir " + QuoteArg(backupDir)
            );
        }

        private async void Update_Click(object sender, RoutedEventArgs e)
        {
            await RunPowerShellScriptInlineAsync(@"installer\windows\scripts\update.ps1");
        }

        private void OpenApp_Click(object sender, RoutedEventArgs e)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "http://localhost:8080",
                UseShellExecute = true
            });
        }

        private void Admin_Click(object sender, RoutedEventArgs e)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "http://localhost:8080/app/user/Administrator",
                UseShellExecute = true
            });
        }

        private void Logs_Click(object sender, RoutedEventArgs e)
        {
            var logs = Path.Combine(RootDir, "logs");

            if (!Directory.Exists(logs))
                Directory.CreateDirectory(logs);

            Process.Start(new ProcessStartInfo
            {
                FileName = logs,
                UseShellExecute = true
            });
        }
    }
}

