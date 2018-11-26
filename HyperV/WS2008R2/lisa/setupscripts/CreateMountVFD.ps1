#######################################################################
#
# CreateMountVFD
#
# Description:
#   Create a VM specific .vfd file if one does not already exist.
#
#   The .vfd file is created in the Hyper-V default location for
#   .vhd files.
#
#   The filename is <vmname>_Floppy.vfd
#
#   If a .vfd file is already mounted in the VMs floppy drive,
#   no error is returned - only a message in the log file.
#
#######################################################################
param([string] $vmName, [string] $hvServer, [string] $testParams)

"CreateMountVFD.ps1 -vmName $vmName -hvServer $hvServer -testParams $testParams"

$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2Sp1\Hyperv.psd1
}

#
# We will create the .vfd files in the default VHD directory
#
$defPath = Get-VHDDefaultPath -server $hvServer
if ($defPath -eq $null)
{
    $defPath = "C:\"
}

$vfdName = $vmName + "_Floppy.vfd"
$vfdPath = Join-Path -path $defPath -childPath $vfdName

#
# Only create the VM specific .vfd if it does not already exist
#
$uncPath = "\\$hvServer\" + ($vfdPath.Replace(":", "$"))
if (-not (test-path -path $uncPath))
{
    $sts = New-VFD -VFDPaths $vfdPath -server $hvServer -wait
    "Created VM specific .vfd file $vfdName"
}

#
# Next, we mount the .vfd if a .vfd is not already mounted
#
$vfd = Get-VMFloppyDisk -vm $vmName -server $hvServer
if ($vfd -eq $null)
{
    $mounted = Add-VMFloppyDisk -vm $vmName -path $vfdPath -server $hvServer -force
    "Mounted .vfd file $vfdName"
}
else
{
    "A .vfd file is already mounted"
}

return $true