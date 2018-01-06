Param
( 
$vhdName,
$testLocation
)

if ( $customSecretsFilePath ) {
    $secretsFile = $customSecretsFilePath
    Write-Host "Using user provided secrets file: $($secretsFile | Split-Path -Leaf)"
}
if ($env:Azure_Secrets_File) {
    $secretsFile = $env:Azure_Secrets_File
    Write-Host "Using predefined secrets file: $($secretsFile | Split-Path -Leaf) in Jenkins Global Environments."
}
if ( $secretsFile -eq $null ) {
    Write-Host "ERROR: Azure Secrets file not found in Jenkins / user not provided -customSecretsFilePath" -ForegroundColor Red -BackgroundColor Black
    exit 1
}
if ( Test-Path $secretsFile) {
    Write-Host "AzureSecrets.xml found."
    .\AddAzureRmAccountFromSecretsFile.ps1 -customSecretsFilePath $secretsFile
    $xmlSecrets = [xml](Get-Content $secretsFile)
    Set-Variable -Name xmlSecrets -Value $xmlSecrets -Scope Global
}
else {
    Write-Host "AzureSecrets.xml file is not added in Jenkins Global Environments OR it is not bound to 'Azure_Secrets_File' variable." -ForegroundColor Red -BackgroundColor Black
    Write-Host "Aborting." -ForegroundColor Red -BackgroundColor Black
    exit 1
}

#region Select Storage Account Type
$regionName = $testLocation.Replace(" ","").Replace('"',"").ToLower()
$regionStorageMapping = [xml](Get-Content .\XML\RegionAndStorageAccounts.xml)
if ($StorageAccount)
{
    if ( $StorageAccount -imatch "ExistingStorage_Standard" )
    {
        $StorageAccountName = $regionStorageMapping.AllRegions.$regionName.StandardStorage
    }
    elseif ( $StorageAccount -imatch "ExistingStorage_Premium" )
    {
        $StorageAccountName = $regionStorageMapping.AllRegions.$regionName.PremiumStorage
    }
    elseif ( $StorageAccount -imatch "NewStorage_Standard" )
    {
        $StorageAccountName = "NewStorage_Standard_LRS"
    }
    elseif ( $StorageAccount -imatch "NewStorage_Premium" )
    {
        $StorageAccountName = "NewStorage_Premium_LRS"
    }
    elseif ($StorageAccount -eq "")
    {
        $StorageAccountName = $regionStorageMapping.AllRegions.$regionName.StandardStorage
        Write-Host "Auto selecting storage account : $StorageAccountName as per your test region."
    }
}
else 
{
    $StorageAccountName = $regionStorageMapping.AllRegions.$regionName.StandardStorage
    Write-Host "Auto selecting storage account : $StorageAccountName as per your test region."    
}

#endregion

Import-Module .\vendortesting.psm1 -Force -Global
$QueueDir = "E:\QueueVHDs"
$uploadedVHDsDir = "E:\UploadedVHDs"
$exitValue = 1
try
{
    $ARMStorageAccount = $StorageAccountName
    LogText -text "Selected storage account for current tests: $ARMStorageAccount"
    LogText -text "Gettting details : Storage account - $ARMStorageAccount"
    $ARMStorageAccountRG = (Get-AzureRmResource | Where { $_.Name -eq $ARMStorageAccount}).ResourceGroupName
    $UploadLink  = "https://$ARMStorageAccount.blob.core.windows.net/vhds"
    $retryUpload = $true
    
    LogText -text "WARNING: If a VHD is present in storage account with same name, it will be overwritten."
    $retryUpload = $true
    $retryCount = 0
    while($retryUpload -and ($retryCount -le 10))
    {
        $retryCount += 1
        LogText -text "Initiating '$vhdName' upload to $UploadLink. Please wait..."
        $out = Add-AzureRmVhd -ResourceGroupName $ARMStorageAccountRG -Destination "$UploadLink/$vhdName" -LocalFilePath "$QueueDir\$vhdName" -NumberOfUploaderThreads 16 -OverWrite -Verbose
        $uploadStatus = $?
        if ( $uploadStatus )
        {
            LogText -text "Upload successful."
            LogText -text "$($out.DestinationUri)"
            $exitValue = 0
            $retryUpload = $false
            LogText -text "Moving file : '$vhdName' --> $uploadedVHDsDir"
            Move-Item -Path "$QueueDir\$vhdName" -Destination "$uploadedVHDsDir" -Force
                        
        }
        else
        {
            LogText -text "ERROR: Something went wrong in upload. Retrying..."
            $retryUpload = $true
            sleep 10
        }
    }
}

catch
{
    Write-Host "$($_.Exception.GetType().FullName, " : ",$_.Exception.Message)"
    exit 1
}
finally
{
    LogText -text "Exiting with code : $exitValue"
    exit $exitValue
}


