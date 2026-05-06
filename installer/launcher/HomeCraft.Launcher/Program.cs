using System.Diagnostics;
using System.Net;
using System.Runtime.InteropServices;

const int DefaultPort = 3000;

var installDir = AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
var appDir = Path.Combine(installDir, "app");
var toolsDir = Path.Combine(installDir, "tools");
var nodeExe = FindNode(toolsDir);
var javaBin = FindJavaBin(toolsDir);
var port = GetPort(args);

Console.Title = "HomeCraft";
Console.WriteLine("HomeCraft Launcher");
Console.WriteLine("==================");
Console.WriteLine();

if (!Directory.Exists(appDir))
{
    Fail($"HomeCraft app folder was not found: {appDir}");
}

if (!Directory.Exists(Path.Combine(appDir, "build")))
{
    Fail($"HomeCraft has not been built yet. Missing folder: {Path.Combine(appDir, "build")}");
}

if (nodeExe is null)
{
    Fail("Node.js was not found. Re-run the HomeCraft installer or bootstrap script.");
}

var configPath = Path.Combine(appDir, ".homecraft", "config.json");
if (!File.Exists(configPath))
{
    Fail($"HomeCraft config was not found: {configPath}");
}

var envPathParts = new List<string>
{
    Path.GetDirectoryName(nodeExe)!,
};

if (javaBin is not null)
{
    envPathParts.Add(javaBin);
}

var currentPath = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
envPathParts.Add(currentPath);

using var process = new Process();
process.StartInfo = new ProcessStartInfo
{
    FileName = nodeExe,
    Arguments = "build",
    WorkingDirectory = appDir,
    UseShellExecute = false,
    RedirectStandardOutput = true,
    RedirectStandardError = true,
    RedirectStandardInput = true,
};
process.StartInfo.Environment["PATH"] = string.Join(Path.PathSeparator, envPathParts);
process.StartInfo.Environment["PORT"] = port.ToString();
process.StartInfo.Environment["NODE_ENV"] = "production";

var stopping = false;
Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
    if (stopping)
    {
        return;
    }

    stopping = true;
    Console.WriteLine();
    Console.WriteLine("Stopping HomeCraft...");
    StopProcessTree(process);
};

process.OutputDataReceived += (_, e) =>
{
    if (!string.IsNullOrWhiteSpace(e.Data))
    {
        Console.WriteLine(e.Data);
    }
};

process.ErrorDataReceived += (_, e) =>
{
    if (!string.IsNullOrWhiteSpace(e.Data))
    {
        Console.Error.WriteLine(e.Data);
    }
};

try
{
    process.Start();
}
catch (Exception ex)
{
    Fail($"Failed to start HomeCraft: {ex.Message}");
}

process.BeginOutputReadLine();
process.BeginErrorReadLine();

Console.WriteLine($"HomeCraft is starting on http://localhost:{port}");
Console.WriteLine("Press Ctrl+C to stop.");
Console.WriteLine();

OpenBrowserWhenReady(port, process);
process.WaitForExit();

Console.WriteLine();
Console.WriteLine($"HomeCraft stopped with exit code {process.ExitCode}.");
Console.WriteLine("Press Enter to close this window.");
Console.ReadLine();
return process.ExitCode;

static int GetPort(string[] args)
{
    for (var i = 0; i < args.Length - 1; i++)
    {
        if (string.Equals(args[i], "--port", StringComparison.OrdinalIgnoreCase) &&
            int.TryParse(args[i + 1], out var port) &&
            port > 0 &&
            port <= 65535)
        {
            return port;
        }
    }

    return DefaultPort;
}

static string? FindNode(string toolsDir)
{
    var candidates = new List<string>
    {
        Path.Combine(toolsDir, "node", "node.exe"),
    };

    if (Directory.Exists(toolsDir))
    {
        candidates.AddRange(Directory.GetFiles(toolsDir, "node.exe", SearchOption.AllDirectories));
    }

    return candidates.FirstOrDefault(File.Exists);
}

static string? FindJavaBin(string toolsDir)
{
    if (!Directory.Exists(toolsDir))
    {
        return null;
    }

    var java = Directory.GetFiles(toolsDir, "java.exe", SearchOption.AllDirectories).FirstOrDefault();
    return java is null ? null : Path.GetDirectoryName(java);
}

static void OpenBrowserWhenReady(int port, Process process)
{
    _ = Task.Run(async () =>
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        var url = $"http://localhost:{port}";

        for (var attempt = 0; attempt < 30 && !process.HasExited; attempt++)
        {
            try
            {
                using var response = await client.GetAsync(url);
                if (response.StatusCode != HttpStatusCode.ServiceUnavailable)
                {
                    OpenUrl(url);
                    return;
                }
            }
            catch
            {
                // Server is still starting.
            }

            await Task.Delay(1000);
        }
    });
}

static void OpenUrl(string url)
{
    try
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = url,
            UseShellExecute = true,
        });
    }
    catch
    {
        Console.WriteLine($"Open this URL in your browser: {url}");
    }
}

static void StopProcessTree(Process process)
{
    try
    {
        if (process.HasExited)
        {
            return;
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "taskkill",
                Arguments = $"/PID {process.Id} /T /F",
                CreateNoWindow = true,
                UseShellExecute = false,
            })?.WaitForExit(5000);
        }
        else
        {
            process.Kill(entireProcessTree: true);
        }
    }
    catch
    {
        try
        {
            process.Kill();
        }
        catch
        {
            // The process may have already exited.
        }
    }
}

static void Fail(string message)
{
    Console.Error.WriteLine(message);
    Console.Error.WriteLine("Press Enter to close this window.");
    Console.ReadLine();
    Environment.Exit(1);
}
