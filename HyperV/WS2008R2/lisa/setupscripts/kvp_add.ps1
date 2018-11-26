############################################################################
#
# 
#
# Description:
#      
#     Add Key Values to pool
#     
#
############################################################################


param([string] $vmName,
[string] $hvServer) 

$retVal = $false

#
# Check input arguments
# 
if (-not $vmName -or $vmName.Length -eq 0)
{
    "Error: VM name is null"
    return $retVal
}


$VMManagementService = Get-WmiObject -class "Msvm_VirtualSystemManagementService" -namespace "root\virtualization" -ComputerName $hvServer
$VMGuest = Get-WmiObject -Namespace root\virtualization -ComputerName $hvServer -Query "Select * From Msvm_ComputerSystem Where ElementName='$vmName'"
$Msvm_KvpExchangeDataItemPath = "\\$hvServer\root\virtualization:Msvm_KvpExchangeDataItem"
$Msvm_KvpExchangeDataItem = ([WmiClass]$Msvm_KvpExchangeDataItemPath).CreateInstance()
$Msvm_KvpExchangeDataItem.Source = 0


## Add KVP Item
write-output "Adding Key 'Name'"
$Msvm_KvpExchangeDataItem.Name = "Kaleem"
$Msvm_KvpExchangeDataItem.Data = "Sainath"
$result = $VMManagementService.AddKvpItems($VMGuest, $Msvm_KvpExchangeDataItem.PSBase.GetText(1))
$job = [wmi]$result.Job
while($job.jobstate -lt 7) {
	$job.get()
} 
if ($job.ErrorCode)
{
    
	write-host "Error: Failed Adding data to pool"
	$retVal = $false
}
else
{
  $job.JobStatus
   $retVal = $true
 } 

 
return $retVal
 
