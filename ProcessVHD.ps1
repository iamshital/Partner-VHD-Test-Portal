Param(
[string]$userFile
)

Import-Module .\vendortesting.psm1 -Force -Global


try
{

    LogText -text "-userFile = '$userFile'"
    $userFile = $userFile.Replace('.xz','')
    $exitValue = 1
    $QueueDir = "E:\QueueVHDs"

    #Convert VHDx files to VHD.
    if ( $userFile.EndsWith("x") -or  $userFile.EndsWith("X") )
    {
        $newFileName = $userFile.TrimEnd("x").TrimEnd("X")
        Remove-Item "$QueueDir\$newFileName" -Force -ErrorAction SilentlyContinue
        LogText -text "Converting '$userFile' --> '$newFileName'. [VHDx to VHD]"
        #Convert-VHD -Path "$QueVHDxPath\$userFile" -DestinationPath "$QueVHDxPath\$newFileName" -VHDType Dynamic
        $convertJob = Start-Job -ScriptBlock { Convert-VHD -Path $args[0] -DestinationPath $args[1] -VHDType Dynamic } -ArgumentList "$QueueDir\$userFile", "$QueueDir\$newFileName"
        while ($convertJob.State -eq "Running")
        {
            LogText -text "'$userFile' --> '$newFileName' is running"
            Sleep -Seconds 5
        }
        
        if ( $convertJob.State -eq "Completed")
        {
            LogText -text "'$userFile' --> '$newFileName' is Succeeded."
            
            $finalVHD = "$QueueDir\$newFileName"
            $exitValue = 0
            LogText -text "Removing '$userFile'..."
            Remove-Item "$QueueDir\$userFile" -Force -ErrorAction SilentlyContinue
        }
        else
        {
            LogText -text "'$userFile' --> '$newFileName' is Failed."
            $exitValue = 1
        }
    }
    else
    {
        LogText -text "'$userFile' is not a VHDx file. No processing required."
        $finalVHD = "$QueueDir\$userFile"
        $vhdInfo = Get-VHD -Path "$QueueDir\$userFile"
        if ( $vhdInfo.VhdType -imatch "Fixed" )
        {
            $ticks = (Get-Date).Ticks
            LogText -text "Converting FIXED '$userFile' to Dynamic. This will reduce the upload time."
            $convertJob = Start-Job -ScriptBlock { Convert-VHD -Path $args[0] -DestinationPath $args[1] -VHDType Dynamic } -ArgumentList "$QueueDir\$userFile", "$QueueDir\$ticks-$userFile"
            while ($convertJob.State -eq "Running")
            {
                LogText -text "'$userFile' [fixed] --> '$ticks-$userFile' [dynamic] is running"
                Sleep -Seconds 5
            }
        
            if ( $convertJob.State -eq "Completed")
            {
                LogText -text "'$userFile' [fixed] --> '$ticks-$userFile' [dynamic] is Succeeded"
                
                $exitValue = 0
                LogText -text "Removing Fixed disk '$userFile'"
                Remove-Item -Path "$QueueDir\$userFile" -Force
                LogText -text "Renaming Dynamic disk '$ticks-$userFile' to '$userFile'"
                Rename-Item -Path "$QueueDir\$ticks-$userFile" -NewName "$userFile" 
                $finalVHD = "$QueueDir\$userFile"
            }
            else
            {
                LogText -text "'$userFile' [fixed] --> '$ticks-$userFile' [dynamic] is Failed"
                $exitValue = 1
            }        
        }
        else
        {
            $finalVHD = "$QueueDir\$userFile"
            LogText -text "'$userFile' is Dynamic VHD file. No processing required."
            $exitValue = 0
        }
    }



    if ($exitValue -eq 0)
    {
        $vhdInfo = Get-VHD -Path $finalVHD -ErrorAction Stop
        LogText -text "Final VHD status-"
        LogText -text "  VhdFormat            :$($vhdInfo.VhdFormat)"
        LogText -text "  VhdType              :$($vhdInfo.VhdType)"
        LogText -text "  FileSize             :$($vhdInfo.FileSize)"
        LogText -text "  Size                 :$($vhdInfo.Size)"
        LogText -text "  LogicalSectorSize    :$($vhdInfo.LogicalSectorSize)"
        LogText -text "  PhysicalSectorSize   :$($vhdInfo.PhysicalSectorSize)"
        LogText -text "  BlockSize            :$($vhdInfo.BlockSize)"

        if ( $vhdInfo.VhdFormat -eq "VHD" -and $vhdInfo.VhdType -eq "Dynamic" )
        {
            LogText -text "'$finalVHD' is ready to push to Azure storage account."
            $exitValue = 0
        }
        else
        {
            LogText -text "Someting went wrong. '$finalVHD' is NOT ready to push Azure storage account."
            $exitValue = 1
        }
        
    } 
}
catch
{
    Write-Host "$($_.Exception.GetType().FullName, " : ",$_.Exception.Message)"
    $exitValue = 1
}
finally
{
    LogText -text "Exiting with code : $exitValue"
    exit $exitValue
}