Import-Module .\vendortesting.psm1 -Force -Global

$exitCode = 1
LogText -text "VHD: $env:VHD"
$tempVHD = ($env:VHD).ToLower()
if ( $tempVHD.EndsWith(".vhd") -or $tempVHD.EndsWith(".vhdx") -or $tempVHD.EndsWith(".xz"))
{
    LogText -text "Copying your file --> Z:\ReceivedFiles\$env:PartnerName-$env:BUILD_NUMBER-$env:VHD"
    Move-Item VHD Z:\ReceivedFiles\$env:PartnerName-$env:BUILD_NUMBER-$env:VHD -Force
    $exitCode = $LASTEXITCODE
}
else 
{
    LogText -text "-----------------ERROR-------------------"
    LogText -text "Error: Filetype : $($tempVHD.Split(".")[$tempVHD.Split(".").Count -1]) is NOT supported."
    LogText -text "Supported file types : vhd, vhdx, xz."
    LogText -text "-----------------------------------------"
    $exitCode = 1
}
exit $exitCode
