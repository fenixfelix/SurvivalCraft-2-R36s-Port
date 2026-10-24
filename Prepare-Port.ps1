param(
    [switch]$Cli,
    [string]$Apk,
    [string]$Output
)
$ErrorActionPreference = 'Stop'
$script:KitRoot = $PSScriptRoot
$script:RecipeHash = '8c3a7d2c4c6bf35d2776d96abecfa68d8ead27613e6be5db8d23a20e7bf2196a'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$compileOptions = @{}
if ($PSVersionTable.PSEdition -ne 'Core') {
    $compileOptions.ReferencedAssemblies = @('System.dll', 'System.Core.dll', 'System.IO.Compression.dll')
}
Add-Type @compileOptions -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;
public static class SC2Patch {
    public static string Hash(byte[] data) {
        using (var h = SHA256.Create()) { return BitConverter.ToString(h.ComputeHash(data)).Replace("-", "").ToLowerInvariant(); }
    }
    public static byte[] ReadEntry(ZipArchive zip, string name, long expected) {
        var e = zip.GetEntry(name);
        if (e == null || e.Length != expected || expected < 0 || expected > 300000000) throw new InvalidDataException("Missing or incompatible ZIP entry: " + name);
        using (var s = e.Open()) using (var m = new MemoryStream()) { s.CopyTo(m); return m.ToArray(); }
    }
    public static byte[] Inflate(byte[] data, int offset, int expected) {
        if (offset < 0 || offset >= data.Length || expected < 0 || expected > 300000000) throw new InvalidDataException("Invalid assembly offset or size.");
        using (var m = new MemoryStream(data, offset, data.Length-offset))
        using (var g = new GZipStream(m, CompressionMode.Decompress)) {
            var result = new byte[expected]; int done=0;
            while (done < expected) { int n=g.Read(result,done,expected-done); if(n==0) throw new InvalidDataException("Truncated original assembly."); done+=n; }
            // Some runtimes read concatenated gzip members. The expected assembly hash is checked separately.
            return result;
        }
    }
    public static byte[] Apply(byte[] original, byte[] compressedPatch, int expected) {
        using(var m=new MemoryStream(compressedPatch))
        using(var g=new GZipStream(m,CompressionMode.Decompress))
        using(var r=new BinaryReader(g))
        using(var output=new MemoryStream()) {
            if (new string(r.ReadChars(4)) != "SCP1") throw new InvalidDataException("Unsupported patch format.");
            while(true) {
                byte tag=r.ReadByte();
                if(tag==69) { if(output.Length != expected || r.BaseStream.ReadByte()!=-1) throw new InvalidDataException("Invalid patch length."); return output.ToArray(); }
                if(tag==67) {
                    uint offset=r.ReadUInt32(), count=r.ReadUInt32();
                    if((ulong)offset+count>(ulong)original.Length || output.Length+count>expected) throw new InvalidDataException("Invalid COPY operation.");
                    output.Write(original,(int)offset,(int)count);
                } else if(tag==65) {
                    uint count=r.ReadUInt32();
                    if(count>expected || output.Length+count>expected) throw new InvalidDataException("Invalid ADD operation.");
                    byte[] block=r.ReadBytes((int)count); if(block.Length!=count) throw new InvalidDataException("Truncated patch.");
                    output.Write(block,0,block.Length);
                } else throw new InvalidDataException("Unknown patch instruction.");
            }
        }
    }
}
'@

function Write-Status([string]$Text) {
    if ($script:StatusBox) { $script:StatusBox.AppendText($Text + [Environment]::NewLine); [System.Windows.Forms.Application]::DoEvents() }
    else { Write-Host $Text }
}

function Prepare-LocalPort([string]$ApkPath, [string]$TargetPath) {
    $ApkPath = [IO.Path]::GetFullPath($ApkPath)
    $TargetPath = [IO.Path]::GetFullPath($TargetPath)
    if (Test-Path -LiteralPath $TargetPath) { throw 'The output folder already exists. Choose a NEW folder. Existing saves will not be overwritten.' }
    $parent = [IO.Path]::GetDirectoryName($TargetPath)
    if (!(Test-Path -LiteralPath $parent -PathType Container)) { throw 'The parent output folder does not exist.' }
    $recipePath = Join-Path $script:KitRoot 'port_recipe.zip'
    if (!(Test-Path -LiteralPath $recipePath)) { throw 'port_recipe.zip is missing. The public tool alone cannot create the port. A compatible recipe with distribution rights is required.' }
    Write-Status 'Verifying the local port recipe...'
    if ((Get-FileHash -LiteralPath $recipePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $script:RecipeHash) { throw 'Recipe checksum mismatch. Use the matching recipe for this version of the tool.' }
    $recipe = [IO.Compression.ZipFile]::OpenRead($recipePath)
    $apkZip = $null
    $staging = $null
    try {
        $entry = $recipe.GetEntry('manifest.json')
        if (!$entry -or $entry.Length -gt 1000000) { throw 'Invalid recipe manifest.' }
        $reader = New-Object IO.StreamReader($entry.Open())
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        if ($manifest.format -ne 1) { throw 'Unsupported recipe version.' }
        Write-Status 'Checking your APK. No files are uploaded.'
        if ((Get-Item -LiteralPath $ApkPath).Length -ne $manifest.apk_size -or (Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.apk_sha256) {
            throw ('Unsupported APK. This prototype requires the exact Android 2.2.10.4 APK used for the existing build. Your APK has not been changed. Expected SHA-256: ' + $manifest.apk_sha256)
        }
        $apkZip = [IO.Compression.ZipFile]::OpenRead($ApkPath)
        $bundleEntry = $apkZip.GetEntry($manifest.bundle_entry)
        if (!$bundleEntry) { throw 'The APK does not contain the expected Xamarin assembly bundle.' }
        $bundle = [SC2Patch]::ReadEntry($apkZip, $manifest.bundle_entry, $bundleEntry.Length)
        $staging = Join-Path $parent ('.sc2-prepare-' + [Guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($staging) | Out-Null
        $gameDir = Join-Path $staging 'survivalcraft2'
        [IO.Directory]::CreateDirectory($gameDir) | Out-Null
        foreach ($assembly in $manifest.assemblies) {
            Write-Status ('Preparing ' + $assembly.name + ' from your APK...')
            if ($assembly.name -notin @('Engine.dll','EntitySystem.dll','Survivalcraft.dll')) { throw 'Unexpected assembly name.' }
            $original = [SC2Patch]::Inflate($bundle, [int]$assembly.gzip_offset, [int]$assembly.base_size)
            if ([SC2Patch]::Hash($original) -ne $assembly.base_sha256) { throw ('Original assembly integrity check failed: ' + $assembly.name) }
            $patchEntry = $recipe.GetEntry($assembly.patch_entry)
            if (!$patchEntry -or $patchEntry.Length -gt 10000000) { throw 'Missing or oversized patch.' }
            $patch = [SC2Patch]::ReadEntry($recipe, $assembly.patch_entry, $patchEntry.Length)
            if ([SC2Patch]::Hash($patch) -ne $assembly.patch_sha256) { throw 'Patch integrity check failed.' }
            $result = [SC2Patch]::Apply($original, $patch, [int]$assembly.target_size)
            if ([SC2Patch]::Hash($result) -ne $assembly.target_sha256) { throw ('Output integrity check failed: ' + $assembly.name) }
            [IO.File]::WriteAllBytes((Join-Path $gameDir $assembly.name), $result)
        }
        Write-Status 'Installing the ARM64 runtime, notices, launcher and default settings...'
        foreach ($property in $manifest.payload.PSObject.Properties) {
            $name = [string]$property.Name
            if ($name -match '(^/|\\|:|(^|/)\.\.(/|$))') { throw 'Invalid payload path.' }
            $spec = $property.Value
            $bytes = [SC2Patch]::ReadEntry($recipe, $spec.entry, [long]$spec.size)
            if ([SC2Patch]::Hash($bytes) -ne $spec.sha256) { throw ('Payload checksum mismatch: ' + $name) }
            $path = Join-Path $staging $name
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
            [IO.File]::WriteAllBytes($path, $bytes)
        }
        $notice = 'LOCAL GAME INSTALLATION - contains original and adapted game content. Do not redistribute without compatible permission. Copy the two .sh files and the survivalcraft2 folder to your ports folder. Existing userdata must be preserved.'
        [IO.File]::WriteAllText((Join-Path $staging 'LOCAL-USE.txt'), $notice)
        [IO.Directory]::Move($staging,$TargetPath)
        $staging = $null
        Write-Status ('Done. Prepared files: ' + $TargetPath)
    } finally {
        if ($apkZip) { $apkZip.Dispose() }
        $recipe.Dispose()
        if ($staging -and (Test-Path -LiteralPath $staging)) { Remove-Item -LiteralPath $staging -Recurse -Force }
    }
}

if ($Cli) {
    if (!$Apk -or !$Output) { throw 'Usage: Prepare-Port.ps1 -Cli -Apk YOUR.apk -Output NEW_FOLDER' }
    Prepare-LocalPort $Apk $Output
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = 'Survivalcraft 2 - R36S APK Preparer (local prototype)'
$form.ClientSize = New-Object Drawing.Size(700,440)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$label = New-Object Windows.Forms.Label
$label.Location = New-Object Drawing.Point(20,15)
$label.Size = New-Object Drawing.Size(660,65)
$label.Text = "Select your own compatible Survivalcraft 2 APK. Files stay on your computer.`r`nThis prototype supports one exact Android 2.2.10.4 build. It does not download the game.`r`nThe recipe and the generated game files are NOT cleared for public distribution."
$form.Controls.Add($label)
$apkBox = New-Object Windows.Forms.TextBox
$apkBox.Location = New-Object Drawing.Point(20,90)
$apkBox.Size = New-Object Drawing.Size(530,24)
$apkBox.ReadOnly = $true
$form.Controls.Add($apkBox)
$browse = New-Object Windows.Forms.Button
$browse.Text = 'Select APK'
$browse.Location = New-Object Drawing.Point(560,88)
$browse.Size = New-Object Drawing.Size(120,28)
$browse.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select your own Survivalcraft 2 APK'
    $dialog.Filter = 'Android package (*.apk)|*.apk'
    if ($dialog.ShowDialog() -eq 'OK') { $apkBox.Text = $dialog.FileName }
    $dialog.Dispose()
})
$form.Controls.Add($browse)
$outputBox = New-Object Windows.Forms.TextBox
$outputBox.Location = New-Object Drawing.Point(20,130)
$outputBox.Size = New-Object Drawing.Size(530,24)
$outputBox.ReadOnly = $true
$form.Controls.Add($outputBox)
$folder = New-Object Windows.Forms.Button
$folder.Text = 'Choose folder'
$folder.Location = New-Object Drawing.Point(560,128)
$folder.Size = New-Object Drawing.Size(120,28)
$folder.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose a parent folder. A NEW Survivalcraft2_R36S folder will be created inside it.'
    if ($dialog.ShowDialog() -eq 'OK') { $outputBox.Text = Join-Path $dialog.SelectedPath 'Survivalcraft2_R36S' }
    $dialog.Dispose()
})
$form.Controls.Add($folder)
$prepare = New-Object Windows.Forms.Button
$prepare.Text = 'Prepare port'
$prepare.Location = New-Object Drawing.Point(20,175)
$prepare.Size = New-Object Drawing.Size(660,36)
$script:StatusBox = New-Object Windows.Forms.TextBox
$script:StatusBox.Location = New-Object Drawing.Point(20,225)
$script:StatusBox.Size = New-Object Drawing.Size(660,190)
$script:StatusBox.Multiline = $true
$script:StatusBox.ScrollBars = 'Vertical'
$script:StatusBox.ReadOnly = $true
$form.Controls.Add($script:StatusBox)
$prepare.Add_Click({
    if (!$apkBox.Text -or !$outputBox.Text) { [Windows.Forms.MessageBox]::Show('Select your APK and an output folder first.','Missing selection') | Out-Null; return }
    $prepare.Enabled = $false; $browse.Enabled = $false; $folder.Enabled = $false
    try {
        Prepare-LocalPort $apkBox.Text $outputBox.Text
        [Windows.Forms.MessageBox]::Show('Preparation complete. Copy the two .sh files and the survivalcraft2 folder to ports. Read README.md before copying to an existing installation.','Done') | Out-Null
    } catch {
        Write-Status ('ERROR: ' + $_.Exception.Message)
        [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Preparation failed') | Out-Null
    } finally { $prepare.Enabled = $true; $browse.Enabled = $true; $folder.Enabled = $true }
})
$form.Controls.Add($prepare)
[void]$form.ShowDialog()
