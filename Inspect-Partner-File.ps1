Param(
[string]$userFile,
[string]$md5sum
)

Import-Module .\vendortesting.psm1 -Force -Global
$sharedDrive = "Z:"
$localDrive = "E:"
$7zExePath = "$pwd\tools\7za.exe"
$VHD = $userFile
$Email = $env:Email   
try
{
    #Prerequisites:
    mkdir -Path .\tools -ErrorAction SilentlyContinue | Out-Null
    mkdir -Path $localDrive\ReceivedFiles -ErrorAction SilentlyContinue | Out-Null
    mkdir -Path $localDrive\QueueVHDs  -ErrorAction SilentlyContinue | Out-Null
    mkdir -Path $sharedDrive\ReceivedFiles -ErrorAction SilentlyContinue | Out-Null
    mkdir -Path $sharedDrive\QueueVHDs  -ErrorAction SilentlyContinue | Out-Null
    

    if (!( Test-Path -Path $7zExePath ))
    {
        Write-Host "Downloading 7za.exe"
        $out = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/iamshital/azure-linux-automation-support-files/raw/master/tools/7za.exe" -OutFile 7za.exe -ErrorAction SilentlyContinue | Out-Null
    }    

    Move-Item -Path "*.exe" -Destination .\tools -ErrorAction SilentlyContinue -Force

    #region VALIDATE ARGUMENTS
    $missingParameters = @()
    $exitValue = 1
    $currentDir = $pwd
    $QueueDir = "$localDrive\QueueVHDs"
    $ReceivedFilesDir = "$localDrive\ReceivedFiles"

    LogText -text "Checking if $sharedDrive\ReceivedFiles\$VHD exists."    
    If((Test-Path "$sharedDrive\ReceivedFiles\$VHD" -ErrorAction SilentlyContinue))
    {
        LogText -text "Copying $sharedDrive\ReceivedFiles\$VHD --> $localDrive\ReceivedFiles."
        Copy-Item -Path "$sharedDrive\ReceivedFiles\$VHD" -Destination $ReceivedFilesDir -Force
        $PartnerName = $VHD.Split("-")[0]
        $BuildNumber = $VHD.Split("-")[1]        
    }
    else 
    {
        LogText -text "$sharedDrive\ReceivedFiles\$VHD not found."
        $missingParameters += "FileName"
    }
    #LogText -text "Checking if -Email is provided."    
    #If($Email -eq $null)
    #{
    #    LogText -text "$Email not provided."
    #    $missingParameters += "Email"
    #}

    if ($missingParameters.Count -gt 0 )
    {
        $j = 1
        
        LogText -text "Following parameters are missing - "
        foreach($parameter in $missingParameters)
        {
            LogText -text "`t$j`t$parameter" 
            $j += 1  
        }
        Throw "MISSING_PARAMETERS_EXCEPTION"
    }
    #endregion

    
    #region DEFINE VARIABLES
    $exitValue = 1
    $currentDir = $pwd 
    #endregion

    LogText -text "User Provided file = $VHD" 
    LogText -text "Email = $Email"     




    if ($VHD)
    {
        LogText -text "Using user provided file '$VHD' ..."
        
        if ( $md5sum)
        {
            LogText -text "Checking file integrity."
            ValidateMD5 -filePath "$ReceivedFilesDir\$VHD" -expectedMD5hash $md5sum
        }
        else
        {
            LogText -text "You did not provide MD5 SUM. Skipping file integrity verification."
        }

        LogText -text "Changing working directory to $ReceivedFilesDir"
        cd $ReceivedFilesDir
        if (($VHD).ToLower().EndsWith("xz"))
        {
            LogText -text "Detected *.xz file."
            LogText -text "Extracting '$VHD'. Please wait..."
            $7zConsoleOuput = Invoke-Expression -Command "$7zExePath -y x '$VHD';" -Verbose
            if ($7zConsoleOuput -imatch "Everything is Ok")
            {
                LogText -text "Extraction completed."
                $newVHDName = $(($VHD).TrimEnd("xz").TrimEnd("."))
                #Rename-Item -Path $newVHDName.Replace("$PartnerName-","").Replace("$BuildNumber-","") -NewName $newVHDName
                LogText -text "Changing working directory to $currentDir"
                cd $currentDir
                $vhdActualSize = ($7zConsoleOuput -imatch "size").Replace(" ",'').Replace(" ",'').Replace(" ",'').Replace(" ",'').Split(":")[1]
                $vhdCompressedSize = ($7zConsoleOuput -imatch "Compressed").Replace(" ",'').Replace(" ",'').Replace(" ",'').Replace(" ",'').Split(":")[1]
                $compressinRatio = ((($vhdCompressedSize/($vhdActualSize-$vhdCompressedSize))*100))
                LogText -text "Compression Ratio : $compressinRatio %"
            }
            else
            {
                Throw "Error: Failed to extract $VHD."
            }
        }
        elseif (($VHD).ToLower().EndsWith("vhd") -or ($VHD).ToLower().EndsWith("vhdx"))
        {
            $newVHDName = $VHD
        }
        else
        {
            LogText -text "$($VHD) is NOT supported. Supported file formats: vhd, vhdx and xz (compressed VHD/VHDX) file."
            Throw "UNSUPPORTED_FILE_EXCEPTION"
        }
        #Validate VHD
        ValidateVHD -vhdPath "$ReceivedFilesDir\$newVHDName"

        LogText -text "Moving $newVHDName to $QueueDir queue directory."
        Move-Item -Path "$ReceivedFilesDir\$newVHDName" -Destination $QueueDir -Force
        if ($? )
        {
            $exitValue = 0    
        }
        else
        {
            $exitValue = 1
        }
    }
    else
    {
        LogText -text "Error: You did not provide any VHD file."
        $exitValue = 1
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
