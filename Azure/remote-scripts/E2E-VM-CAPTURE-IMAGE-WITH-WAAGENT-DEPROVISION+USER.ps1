﻿<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$NewUserTestResult = ""
$OldUserTestResult = ""
$OldUserLoginStatus = ""
$NewUserLoginStatus = ""
$resultArr = @()

$olduser = $user
$newuser = "NewAutomationUser"
$BaseOsImageName = GetOSImageFromDistro -Distro $Distro -xmlConfig $xmlConfig

#Deploy A new VM..
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig

<#
Use following deployment for debuggging purpose. You need to comment out upper line in this case.
$isDeployed = DeployVMS -setupType setupType -Distro $Distro -xmlConfig $xmlConfig #Debug Code
$isDeployed = "ICA-ExtraSmallVM-Suse12PL-8-7-0-18-33" #Debug Code
#>
              
#Start Test if Deployment is successfull.

if ($isDeployed)
{
#region COLLECTE DEPLOYED VM DATA
    $testServiceData = Get-AzureService -ServiceName $isDeployed

    #Get VMs deployed in the service..
    $testVMsinService = $testServiceData | Get-AzureVM

    $hs1vm1 = $testVMsinService
    $hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
    $hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
    $hs1VIP = $hs1vm1Endpoints[0].Vip
    $hs1ServiceUrl = $hs1vm1.DNSName
    $hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
    $hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
#endregion
#First VMs deployed in the service..
	try
	{
		$out = RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files .\remote-scripts\temp.txt -username $user -password $password -upload 2>&1 | Out-Null
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo 2>&1 | Out-Null

		#region Deprovision
		LogMsg "Executing: waagent -deprovision+user..."
		$WADeprovisionInfo = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "/usr/sbin/waagent -force -deprovision+user" -runAsSudo #2>&1 | Out-Null
			
		LogMsg $WADeprovisionInfo
		LogMsg "** Execution of waagent -deprovision+user done successfully **"
		#endregion
		
		#region Capture Image
		$CaptureVMImageName = CaptureVMImage -ServiceName $hs1vm1.ServiceName
		LogMsg "Captured Image Name: $CaptureVMImageName" 
		#endregion 
		
	#region for deployment of new VM....
	#Deploy A New VM with captured image after this line..   
		write-host "Deployment of A New VM with diffrent user name using captured image started..."
		LogMsg "Deployment of A New VM with diffrent user name using captured image started..."
		
	#Providing new user name for new deployement     
		$xmlConfig.config.Azure.Deployment.Data.UserName = $newuser
		LogMsg "newuser: $newuser `t user: $user `t olduser: $olduser"
		
	#Passing the captured image name for new deployement
		$newOsImage = SetOSImageToDistro -Distro $Distro -xmlConfig $xmlConfig -ImageName $CaptureVMImageName
		LogMsg "newOsImage: $newOsImage"
		$isNewDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
		#resetting of Base OS image name
		$oldOsImage = SetOSImageToDistro -Distro $Distro -xmlConfig $xmlConfig -ImageName $BaseOsImageName 
		if ($isNewDeployed)
		{
			try
			{
            
			#region Get New Deployment Information
				$NewtestServiceData = Get-AzureService -ServiceName $isNewDeployed
				
			#Get VM deployed in the service..
				$NewtestVMsinService = $NewtestServiceData | Get-AzureVM 
				$hs2vm1 = $NewtestVMsinService
				$hs2vm1Endpoints = $hs2vm1 | Get-AzureEndpoint
				$hs2vm1sshport = GetPort -Endpoints $hs2vm1Endpoints -usage ssh 
				$hs2VIP = $hs2vm1Endpoints[0].Vip
				$hs2ServiceUrl = $hs2vm1.DNSName
				$hs2ServiceUrl = $hs2ServiceUrl.Replace("http://","")
				$hs2ServiceUrl = $hs2ServiceUrl.Replace("/","")
			#endregion
			
			#region for New User Login Check....   
				try
				{
					write-host "Verifying the new user should able to login started ..."
					LogMsg "Verifying the new user should able to login started ..."
					$out = RemoteCopy -uploadTo $hs2VIP -port $hs2vm1sshport -files .\remote-scripts\temp.txt -username $newuser -password $password -upload 2>&1 | Out-Null
					$NewUserLoginStatus = RunLinuxCmd -username $newuser -password $password -ip $hs2VIP -port $hs2vm1sshport -command "/usr/sbin/waagent -version" -runAsSudo 
					if($NewUserLoginStatus)
					{
						$NewUserTestResult = "PASS"
						LogMsg "New user able to login into VM..."
						$metaData = "NewUser : $newuser should able to login"
					}
					else
					{
						$NewUserTestResult = "FAIL"
						LogErr "New user unable to login into VM..."
						$metaData = "NewUser : $newuser should able to login"
					}
				}
				catch
				{
					$NewUserTestResult = "Aborted"
					LogErr "New user unable to login into VM..."
					$metaData = "NewUser : $newuser should able to login"
				}
				#resetting of User name
				$user = $olduser
				$resultArr += $NewUserTestResult
				$resultSummary +=  CreateResultSummary -testResult $NewUserTestResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
			#endregion
			
			#region for Old User Login Check....
				try
				{
					write-host "Verifying old user should not able to login started..."
					LogMsg "Verifying old user should not able to login started..."
					$OldUserLoginStatus = RunLinuxCmd -username $user -password $password -ip $hs2VIP -port $hs2vm1sshport -command "/usr/sbin/waagent -version" -runAsSudo #2>&1 | Out-Null
					
					if($OldUserLoginStatus)
					{
						$OldUserTestResult = "FAIL"
						LogErr "Old user able to login into VM..."
						$metaData = "OldUser : $user should not able to login"
					}
					else
					{
						$OldUserTestResult = "PASS"
						LogMsg "Old user unable to login into VM..."
						$metaData = "OldUser : $user should not able to login"
					}
				}
				catch
				{
					if(!$OldUserLoginStatus)
					{
						$OldUserTestResult = "PASS"
						LogMsg "Old user unable to login into VM..."
						$metaData = "OldUser : $user should not able to login"
					}
				}
				$resultArr += $OldUserTestResult
				$resultSummary +=  CreateResultSummary -testResult $OldUserTestResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName # if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
			}
			catch
			{
				$ErrorMessage =  $_.Exception.Message
				LogMsg "EXCEPTION : $ErrorMessage"   
			}
		#endregion
			if ($NewUserTestResult -eq "PASS" -and $OldUserTestResult -eq "PASS")
			{
				$testResult = "PASS"
			}
            else{
                $testResult = "FAIL"
            }
		}
		else
		{
			$testResult = "Aborted"
		}
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		#$metaData = ""
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
	}
}
else
{
	if (!$testResult)
	{
		$testResult = "Aborted"
		$resultArr += $testResult
	}
}
$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
$xmlConfig.config.Azure.Deployment.Data.UserName = $newuser        
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isNewDeployed
$xmlConfig.config.Azure.Deployment.Data.UserName = $olduser   
#Return the result and summery to the test suite script..
return $result, $resultSummary