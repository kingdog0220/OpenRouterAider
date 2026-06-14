# OpenRouter + Aider container rebuild and enter
# Usage: .\openrouter_start.ps1
$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = if ($env:OPENROUTER_START_LOG) {
    $env:OPENROUTER_START_LOG
} else {
    Join-Path -Path $rootDir -ChildPath "openrouter_start.log"
}
$transcriptStarted = $false
try {
    Start-Transcript -Path $LogFile -Append
    $transcriptStarted = $true

    Set-Location -Path $rootDir

# Add Windows Forms assembly for InputBox dialog
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

# Get current HOST_DIR from .env file
$envFile = ".\.env"
$currentHostDir = $rootDir

if (Test-Path $envFile) {
    $envContent = Get-Content $envFile
    $matchLine = $envContent | Select-String "^HOST_DIR=" | Select-Object -First 1
    if ($matchLine) {
        $currentHostDir = $matchLine -replace "^HOST_DIR=", ""
    }
}

# Function to fetch models from OpenRouter API
function Get-OpenRouterModels {
    try {
        $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/models" -Method GET
        # Ensure response.data exists and is not null
        if ($null -eq $response -or $null -eq $response.data) {
            Write-Host "Invalid API response format" -ForegroundColor Yellow
            return @("openrouter/free")  # Return default model
        }
        # Filter to models usable for inference (text output capable)
        $models = @(
            $response.data |
            Where-Object {
                $_.architecture -and
                $_.architecture.output_modalities -and
                ($_.architecture.output_modalities -contains "text")
            } |
            Sort-Object id |
            ForEach-Object { $_.id }
        )
        # If no models found, return default
        if ($models.Count -eq 0) {
            Write-Host "No models found in API response" -ForegroundColor Yellow
            return @("openrouter/free")
        }
        return $models
    }
    catch {
        Write-Host "Failed to fetch models from OpenRouter API: $_" -ForegroundColor Red
        return @("openrouter/free")  # Default model if API fails
    }
}

# Show input dialog with current value as default
$form = New-Object System.Windows.Forms.Form
$form.Text = "OpenRouter Configuration"
$form.Width = 500
$form.Height = 240
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# Label for HOST_DIR
$label = New-Object System.Windows.Forms.Label
$label.Text = "HOST_DIR:"
$label.Left = 20
$label.Top = 20
$label.Width = 100
$form.Controls.Add($label)

# TextBox for HOST_DIR
$textbox = New-Object System.Windows.Forms.TextBox
$textbox.Left = 20
$textbox.Top = 50
$textbox.Width = 360
$textbox.Text = $currentHostDir
$form.Controls.Add($textbox)

# Browse Button
$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Browse"
$browseButton.Left = 395
$browseButton.Top = 46
$browseButton.Width = 75
$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select HOST_DIR"
    $folderBrowser.SelectedPath = $textbox.Text
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textbox.Text = $folderBrowser.SelectedPath -replace "\\", "/"
    }
})
$form.Controls.Add($browseButton)

# Label for Model
$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "Model:"
$modelLabel.Left = 20
$modelLabel.Top = 90
$modelLabel.Width = 100
$form.Controls.Add($modelLabel)

# ComboBox for Model selection
$modelComboBox = New-Object System.Windows.Forms.ComboBox
$modelComboBox.Left = 20
$modelComboBox.Top = 120
$modelComboBox.Width = 450
$modelComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($modelComboBox)

# Populate models
$models = Get-OpenRouterModels
$modelComboBox.Items.AddRange($models)
if ($models.Count -gt 0) {
    $modelComboBox.SelectedIndex = 0
} else {
    # Add default model if no models available
    $modelComboBox.Items.Add("openrouter/free")
    $modelComboBox.SelectedIndex = 0
}

# OK Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Left = 310
$okButton.Top = 160
$okButton.Width = 75
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

# Cancel Button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Left = 400
$cancelButton.Top = 160
$cancelButton.Width = 75
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

# Show dialog
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $newHostDir = $textbox.Text
    $selectedModel = $modelComboBox.SelectedItem

    # Ensure selected model is not null
    if ($null -eq $selectedModel) {
        $selectedModel = "openrouter/free"
        Write-Host "No model selected, using default: $selectedModel" -ForegroundColor Yellow
    }

    if (-not (Test-Path $newHostDir)) {
        $message = "Directory not found: $newHostDir"
        Write-Host $message -ForegroundColor Red
        throw $message
    }

    $projectRulesPath = Join-Path $newHostDir "PROJECT_RULES.md"
    $projectRulesTemplate = Join-Path $rootDir "PROJECT_RULES.md"

    if (-not (Test-Path $projectRulesPath)) {
        Write-Host "Copying PROJECT_RULES.md..." -ForegroundColor Cyan
        Copy-Item `
            -Path $projectRulesTemplate `
            -Destination $projectRulesPath
    }
    
    # Update .env file if value changed
    if ($newHostDir -ne $currentHostDir) {
        Write-Host "Updating HOST_DIR in .env..." -ForegroundColor Cyan
        
        if (Test-Path $envFile) {
            $envContent = Get-Content $envFile
            $updatedContent = $envContent -replace "^HOST_DIR=.*", "HOST_DIR=$newHostDir"
            Set-Content -Path $envFile -Value $updatedContent -Encoding UTF8
            Write-Host "HOST_DIR updated to: $newHostDir" -ForegroundColor Green
        }
    }
    
    Write-Host "`nRebuilding and starting container..." -ForegroundColor Cyan
    docker compose down
    docker compose up -d --build
    
    Write-Host "`nContainer started successfully" -ForegroundColor Green
    Write-Host "Entering container..." -ForegroundColor Cyan
    docker compose run --rm aider --config /config/.aider.conf.yml --model "openrouter/$selectedModel"
} else {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
}

} finally {
    if ($transcriptStarted) {
        Stop-Transcript
    }
}
