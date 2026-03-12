<# ================================================================================
  Windows 11 Activation Utility
===================================================================================
Description:
  Performs controlled activation of the Windows operating system to
  Enterprise licensing using approved administrative procedures.

Key Features:
  - Mandatory administrative privilege enforcement
  - Mandatory explicit user authorization prior to execution
  - Enforced UTF-8 encoding for consistent output handling
  - Enforced interactive script exit confirmation

Compatibility:
  - Windows PowerShell 5.1 through PowerShell 7.x
  - Windows Client: Windows 8 through Windows 11
  - Windows Server: 2012 R2 through 2022

Author:
  DigitalZolic

Version:
  10.0

Last Updated:
  2026-02-07

Usage Notice:
  This script performs privileged system and licensing operations.
  It is intended for authorized personnel only.

  Ensure compliance with all applicable organizational policies,
  licensing agreements, and legal requirements before execution.
================================================================================ #>

# ======================================================
# SECTION 0 - GLOBAL CONTROLS
# ======================================================

Set-StrictMode -Version 2.0
$Global:DefaultSeparator = " / "
$ErrorActionPreference = 'Stop'

# ======================================================
# SECTION 1 - EXPLICIT ADMIN CHECK
# ======================================================

function Assert-Administrator {

    # --------------------------------------------------
    # Ensure execution from a script file
    # --------------------------------------------------
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        throw "Administrator elevation requires execution from a .ps1 file."
    }

    # --------------------------------------------------
    # Detect current privilege level
    # --------------------------------------------------
    $currentIdentity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

    $isAdministrator = $currentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if ($isAdministrator) {
        Write-Host
        return
    }

    # --------------------------------------------------
    # Prevent elevation relaunch loop
    # --------------------------------------------------
    if ($env:__ELEVATED_RELAUNCH -eq '1') {
        throw "Administrator elevation was cancelled or failed."
    }

    Write-Host "Administrator privileges are required." -ForegroundColor Yellow
    Write-Host "Requesting elevation..." -ForegroundColor Yellow

    # --------------------------------------------------
    # Select correct PowerShell executable
    # --------------------------------------------------
    try {
        if ($PSVersionTable.PSEdition -eq 'Core') {
            $psExecutable = (Get-Command pwsh -ErrorAction Stop).Source
        }
        else {
            $psExecutable = (Get-Command powershell -ErrorAction Stop).Source
        }
    }
    catch {
        throw "Unable to locate PowerShell executable."
    }

    # --------------------------------------------------
    # Preserve original bound + unbound parameters
    # --------------------------------------------------
    $argumentList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`""
    )

    # Add bound parameters
    foreach ($key in $PSBoundParameters.Keys) {
        $value = $PSBoundParameters[$key]

        if ($value -is [System.Management.Automation.SwitchParameter]) {
            if ($value.IsPresent) {
                $argumentList += "-$key"
            }
        }
        else {
            $escapedValue = '"' + ($value.ToString() -replace '"','\"') + '"'
            $argumentList += "-$key"
            $argumentList += $escapedValue
        }
    }

    # Add unbound arguments
    foreach ($argument in $MyInvocation.UnboundArguments) {
        $escaped = '"' + ($argument -replace '"','\"') + '"'
        $argumentList += $escaped
    }

    # --------------------------------------------------
    # Set relaunch flag (inherited by child process)
    # --------------------------------------------------
    $env:__ELEVATED_RELAUNCH = '1'

    # --------------------------------------------------
    # Relaunch elevated
    # --------------------------------------------------
    try {
        Start-Process `
            -FilePath $psExecutable `
            -Verb RunAs `
            -ArgumentList $argumentList `
            -WindowStyle Normal | Out-Null
    }
    catch {
        throw "Failed to relaunch script with elevated privileges."
    }

    exit
}

# ------------------------------------------------------
# Exit Point - Administrator
Assert-Administrator

# ======================================================
# SECTION 2 - USER CONSENT GUARD
# ======================================================

function Assert-ExplicitConsent {
    [CmdletBinding()]
    param (
        [string]$ConsentPhrase = 'I Confirm',
        [string]$ExitPhrase    = 'Exit',
        [string]$ExplicitConsent,
        [string]$EnvVarName = 'PS_EXPLICIT_CONSENT'
    )

    $isInteractive =
        [Environment]::UserInteractive -and
        -not [Console]::IsInputRedirected

    # ==================================================
    # Non-interactive authorization path
    # ==================================================
    if (-not $isInteractive) {

        $envConsent = if ($EnvVarName) {
            [Environment]::GetEnvironmentVariable($EnvVarName, 'Process')
        }

        if ($ExplicitConsent -ceq $ConsentPhrase -or
            $envConsent     -ceq $ConsentPhrase) {

            Write-Verbose "Explicit consent validated (non-interactive)."

            return
        }

        throw @"
Explicit user consent is required.

Non-interactive execution detected.
You must provide consent using ONE of the following:

1) Script parameter:
   -ExplicitConsent "$ConsentPhrase"

2) Environment variable:
   $EnvVarName="$ConsentPhrase"

Execution aborted.
"@
    }

    Write-Host
    Write-Host "=======================================" -ForegroundColor Yellow
    Write-Host "     Windows 11 Activation Utility     "
    Write-Host "                                       "
    Write-Host "        Author: DigitalZolic           "
    Write-Host "        Discord: DigitalZolic          "
    Write-Host "        Github: DigitalZolic           "
    Write-Host "=======================================" -ForegroundColor Yellow
    Write-Host
    Write-Host "WARNING: User Authorization Required" -ForegroundColor Red
    Write-Host "This script will perform administrative operations for Windows 11 Activation." -ForegroundColor Red
    Write-Host
    Write-Host " - Clearing existing Windows product key(s) from the system and registry."
    Write-Host " - Clearing Windows licensing and KMS configuration settings."
    Write-Host " - Installing new Windows licensing and KMS configuration settings."
    Write-Host " - Initiating selected Windows Home, Pro or Enterprise activation procedures."
    Write-Host
    Write-Host "By proceeding, you confirm that:" -ForegroundColor Red
    Write-Host " - You are authorized to run this script on this system."
    Write-Host " - You understand the operations being performed."
    Write-Host " - You have obtained all required organizational approvals."
     Write-Host
    Write-Host "To confirm and continue type: $ConsentPhrase"
    Write-Host "To cancel and exit type: $ExitPhrase"
    Write-Host

    while ($true) {
        $userInput = Read-Host "Authorization command"
        $command   = $userInput.Trim()

        # Case-sensitive comparison enforced here
        if ($command -ceq $ConsentPhrase) {
            Write-Host
            Write-Host "Authorization confirmed. Continuing execution..." -ForegroundColor Green
            Write-Host

            return
        }

        if ($command -ceq $ExitPhrase) {
            Write-Host
            Write-Host "Execution cancelled by user." -ForegroundColor Red
            Write-Host
            throw "User cancelled execution."
        }

        Write-Host "Invalid input. Type '$ConsentPhrase' or '$ExitPhrase'." -ForegroundColor Red
    }
}

# ------------------------------------------------------
# Exit Point - User Authorization
Assert-ExplicitConsent

# ======================================================
# SECTION 3 - SYSTEM ENCODING
# ======================================================

function Use-Utf8 {
    [CmdletBinding()]
    param ()

    # -----------------------------------------------------------------
    # UTF-8 Encoding Instance
    # -----------------------------------------------------------------
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    # -----------------------------------------------------------------
    # Console Output Encoding
    # -----------------------------------------------------------------
    try {
        [Console]::OutputEncoding = $utf8NoBom
    }
    catch {
        # The host does not expose a writable console
        # (ISE, remoting, scheduled tasks, services).
    }

    # -----------------------------------------------------------------
    # Native Command Interoperability
    # -----------------------------------------------------------------
    try {
        $global:OutputEncoding = $utf8NoBom
    }
    catch {
        # Extremely constrained environments may block this.
    }

    # -----------------------------------------------------------------
    # PowerShell Cmdlet Default Encoding
    # -----------------------------------------------------------------
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        try {
            $global:PSDefaultParameterValues['*:Encoding'] = 'utf8'
        }
        catch {
            # Defensive no-op
        }
    }
}

# ------------------------------------------------------
# Exit Point - UTF8 Encoding
Use-Utf8

# ======================================================
# SECTION 4 - EXECUTION START
# ======================================================

function Resolve-SystemCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    try {
        $command = Get-Command -Name $Name -CommandType Application,ExternalScript -ErrorAction Stop
        return $command.Source
    }
    catch {
        throw "Required system command not found or not accessible: $Name"
    }
}

# ======================================================
# SECTION 5 - Resolve required Windows licensing components
# ======================================================

$slmgr   = Resolve-SystemCommand 'slmgr.vbs'
$cscript = Resolve-SystemCommand 'cscript.exe'

# ======================================================
# SECTION 6 - Execution results tracking
# ======================================================

$script:ExecutionResults = @()

# ======================================================
# SECTION 7 - Step execution wrapper
# ======================================================

function Run-Step {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Label,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Arguments
    )

    Write-Host
    Write-Host "==== $Label ====" -ForegroundColor Yellow

    $argList = @(
        '//nologo'
        "`"$slmgr`""
        $Arguments
    )

    $exitCode = $null
    $success  = $false
    $errorMsg = $null

    try {
        $process = Start-Process `
            -FilePath $cscript `
            -ArgumentList $argList `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -ErrorAction Stop

        $exitCode = $process.ExitCode
        $success  = ($exitCode -eq 0)
    }
    catch {
        $errorMsg = $_.Exception.Message
    }

    # No [SUCCESS] or [FAILED] messages printed

    # Log execution results silently
    $script:ExecutionResults += [pscustomobject]@{
        Step     = $Label
        Command  = $Arguments
        Success  = $success
        ExitCode = $exitCode
        Error    = $errorMsg
    }
}

# ======================================================
# SECTION 8 - Console preparation
# ======================================================

try {
    if ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected) {
        Clear-Host
    }
}
catch {
    # Non-interactive or constrained host
}

# ======================================================
# SECTION 9 - Action Selection
# ======================================================

Write-Host
Write-Host "Select Edition:" -Foregroundcolor Yellow
Write-Host "1. Windows 11 - Enterprise"
Write-Host "2. Windows 11 - Pro"
Write-Host "3. Windows 11 - Home"
Write-Host
Write-Host "4. Full Activation Reset + Reboot"
Write-Host

do {
    $ActionChoice = Read-Host "Enter selection number (1-4)"
} until ($ActionChoice -match '^[1-4]$')

# ======================================================
# SECTION 10 - Version Mapping
# ======================================================

switch ($ActionChoice) {
    "1" {
        $SelectedVersion = "Windows 11 Enterprise"
        $ProductKey = "NPPR9-FWDCX-D2C8J-H872K-2YT43"
    }
    "2" {
        $SelectedVersion = "Windows 11 Pro"
        $ProductKey = "W269N-WFGWX-YVC9B-4J6C9-T83GX"
    }
    "3" {
        $SelectedVersion = "Windows 11 Home"
        $ProductKey = "TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"
    }
}

# ======================================================
# SECTION 11 - Execution
# ======================================================

Write-Host

if ($ActionChoice -eq "4") {
    Write-Host "===== WINDOWS ACTIVATION RESET =====" -ForegroundColor Yellow
}
else {
    Write-Host "===== $SelectedVersion ACTIVATION =====" -ForegroundColor Yellow
}

if ($ActionChoice -eq "4") {

    Write-Host
    Write-Host "Running Full Activation Reset..." -ForegroundColor Yellow

    Run-Step "Clearing Product Key from System"   "/upk"
    Run-Step "Clearing Product Key from Registry" "/cpky"
    Run-Step "Clearing KMS Server Address"        "/ckms"
    Run-Step "Resetting Activation State"         "/rearm"

    Write-Host
    Write-Host "Rebooting system in 10 seconds..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    Restart-Computer -Force
    # No exit needed; system will reboot
}
else {

    Run-Step "Clearing Product Key from System"   "/upk"
    Run-Step "Clearing Product Key from Registry" "/cpky"
    Run-Step "Clearing KMS Server Address"        "/ckms"
    Run-Step "Setting New KMS Server Address"     "/skms kms8.msguides.com"
    Run-Step "Installing $SelectedVersion Product Key" "/ipk $ProductKey"
    Run-Step "Activating Windows" "/ato"

    Write-Host
    Write-Host "Activation process completed." -ForegroundColor Green

    Write-Host
    Write-Host "Execution Summary:" -ForegroundColor Yellow
    $script:ExecutionResults | Format-Table Step,Success,ExitCode -AutoSize

    # ======================================================
    # SECTION 12 - WAIT FOR EXIT
    # ======================================================
    function Confirm-Exit {
        [CmdletBinding()]
        param ()

        # Require interactive session
        if (-not [Environment]::UserInteractive) {
            return
        }

        # Prevent Ctrl+C termination
        $originalCtrlC = [Console]::TreatControlCAsInput
        [Console]::TreatControlCAsInput = $true

        try {

            Write-Host
            Write-Host "      Script Execution Completed       " -ForegroundColor Green
            Write-Host
            Write-Host "=======================================" -ForegroundColor Yellow
            Write-Host "     Windows 11 Activation Utility     "
            Write-Host "                                       "
            Write-Host "        Author: DigitalZolic           "
            Write-Host "        Discord: DigitalZolic          "
            Write-Host "        Github: DigitalZolic           "
            Write-Host "=======================================" -ForegroundColor Yellow
            Write-Host
            Write-Host 'Type "Exit" to close the script.' -ForegroundColor Green
            Write-Host

            while ($true) {
                $userInput = Read-Host "Command"

                # Only allow EXACT match
                if ($userInput -ceq 'Exit') {
                    Write-Host
                    Write-Host "Exit confirmed. Closing script." -ForegroundColor Green
                    break
                }
                # Ignore other input
            }
        }
        finally {
            # Restore Ctrl+C behavior
            [Console]::TreatControlCAsInput = $originalCtrlC
        }

        return
    }

    # Call exit confirmation for non-reboot actions
    Confirm-Exit
}