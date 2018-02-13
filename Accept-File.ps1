Import-Module .\vendortesting.psm1 -Force -Global

$exitCode = 0

$env:PartnerName
$env:BUILD_NUMBER
if ($env:AzureImage -eq $null -and $env:VHD -eq $null)
{
    LogText -text "---------------------------------------------------------------------"
    LogText -text "Error: Please upload a VHD file or choose AzureImage from the list."
    LogText -text "---------------------------------------------------------------------"
    $exitCode += 1
    exit $exitCode
}
if ($env:TestKernelLocalFile)
{
    if (!($env:TestKernelLocalFile.EndsWith(".deb")) -and !($env:TestKernelLocalFile.EndsWith(".rpm")))
    {
        LogText -text "-----------------------------------------------------------------------------------------------------------"
        LogText -text "Error: .$($env:TestKernelLocalFile.Split(".")[$env:TestKernelLocalFile.Split(".").Count -1]) file is not supported."
        LogText -text "-----------------------------------------------------------------------------------------------------------"
        $exitCode += 1
        exit $exitCodea
    }
    else
    {
        if ($env:TestKernelLocalFile.EndsWith(".deb"))
        {
            $testKernel = "$env:PartnerName-$env:BUILD_NUMBER-testKernel-$env:TestKernelLocalFile"
            LogText -text "Renaming TestKernelLocalFile --> $testKernel"
            Rename-Item -Path TestKernelLocalFile -NewName $testKernel
        }
        if ($env:TestKernelLocalFile.EndsWith(".rpm"))
        {
            $testKernel = "$env:PartnerName-$env:BUILD_NUMBER-testKernel-$env:TestKernelLocalFile"
            LogText -text "Renaming  TestKernelLocalFile --> $testKernel"
            Rename-Item -Path TestKernelLocalFile -NewName $testKernel
        }
    }
}
if ($env:TestKernelRemoteURL)
{
    if (!($env:TestKernelRemoteURL.EndsWith(".deb")) -and !($env:TestKernelRemoteURL.EndsWith(".rpm")))
    {
        LogText -text "-----------------------------------------------------------------------------------------------------------"
        LogText -text "Error: .$($env:TestKernelRemoteURL.Split(".")[$env:TestKernelRemoteURL.Split(".").Count -1]) file is NOT supported."
        LogText -text "-----------------------------------------------------------------------------------------------------------"
        $exitCode += 1
        exit $exitCode
    }
    else
    {
        LogText "Downloading $($env:TestKernelRemoteURL)"
        $out = Invoke-WebRequest -UseBasicParsing -Uri "$env:TestKernelRemoteURL" -OutFile $($env:TestKernelRemoteURL.Split("/")[$env:TestKernelRemoteURL.Split("/").Count -1]) -ErrorAction SilentlyContinue | Out-Null
        if ($?)
        {
            if ($env:TestKernelRemoteURL.EndsWith(".deb"))
            {
                $testKernel = "$env:PartnerName-$env:BUILD_NUMBER-testKernel-$($env:TestKernelRemoteURL.Split("/")[$env:TestKernelRemoteURL.Split("/").Count -1])"
                LogText -text "Renaming $($env:TestKernelRemoteURL.Split("/")[$env:TestKernelRemoteURL.Split("/").Count -1]) --> $testKernel"
                Rename-Item -Path $($env:TestKernelRemoteURL.Split("/")[$env:TestKernelRemoteURL.Split("/").Count -1]) -NewName $testKernel
            }            if ($env:TestKernelRemoteURL.EndsWith(".rpm"))
            {
                $testKernel = "$env:PartnerName-$env:BUILD_NUMBER-testKernel-$($env:TestKernelRemoteURL.Split("/")[$env:TestKernelRemoteURL.Split("/").Count -1])"
                LogText -text "Renaming $($env:TestKernelRemoteURL.Split("/")[$env:TestKernelRemoteURL.Split("/").Count -1]) --> $testKernel"
                Rename-Item -Path $($env:TestKernelRemoteURL.Split("/")[$env:TestKernelRemoteURL.Split("/").Count -1]) -NewName $testKernel
            }
        }
        else
        {
            LogText -text "--------------------------------------------------------------------------------------------------------------"
            LogText "ERROR: Failed to download $($env:TestKernelRemoteURL). Please verify that your URL is accessible on public internet."
            LogText -text "--------------------------------------------------------------------------------------------------------------"
            $exitCode += 1
            exit $exitCode
        }
    }
}
if ($testKernel)
{
    $out = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/iamshital/azure-linux-automation/raw/master/AddAzureRmAccountFromSecretsFile.ps1" -OutFile AddAzureRmAccountFromSecretsFile.ps1 -ErrorAction SilentlyContinue | Out-Null
    $out = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/iamshital/azure-linux-automation/raw/master/Extras/UploadFilesToStorageAccount.ps1" -OutFile UploadFilesToStorageAccount.ps1 -ErrorAction SilentlyContinue | Out-Null
    .\UploadFilesToStorageAccount.ps1 -filePaths $testKernel -destinationStorageAccount konkasoftpackages -destinationContainer partner -destinationFolder Partner $env:PartnerName
}
if ($env:VHD)
{
    LogText -text "VHD: $env:VHD"
    $tempVHD = ($env:VHD).ToLower()
    if ( $tempVHD.EndsWith(".vhd") -or $tempVHD.EndsWith(".vhdx") -or $tempVHD.EndsWith(".xz"))
    {
        LogText -text "Copying your file --> Z:\ReceivedFiles\$env:PartnerName-$env:BUILD_NUMBER-$env:VHD"
        Move-Item VHD Z:\ReceivedFiles\$env:PartnerName-$env:BUILD_NUMBER-$env:VHD -Force
        if ($testKernel)
        {
            LogText -text "Copying $testKernel --> Z:\ReceivedFiles\$testKernel"
            Move-Item $testKernel Z:\ReceivedFiles\$testKernel -Force
        }
        $exitCode = 0
    }
    else
    {
        LogText -text "-----------------ERROR-------------------"
        LogText -text "Error: Filetype : $($tempVHD.Split(".")[$tempVHD.Split(".").Count -1]) is NOT supported."
        LogText -text "Supported file types : vhd, vhdx, xz."
        LogText -text "-----------------------------------------"
        $exitCode = 1
    }
}
if ($env:AzureImage)
{
    LogText -text "AzureImage: $env:AzureImage"
}
exit $exitCode