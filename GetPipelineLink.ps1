param
(
    [string]$pipelineName
)
Import-Module .\vendortesting.psm1 -Force -Global

$buildURLSplitted = $env:BUILD_URL.Replace('https://','').Replace('http://','').Split('/')
$ciURL = $buildURLSplitted[0]
$pipelineID = ([int](Get-Content -Path "C:\Jenkins\jobs\$pipelineName\nextBuildNumber"))
$finalURL = "http://" + "$ciURL" + "/blue/organizations/jenkins" + "/$pipelineName" + "/detail" + "/$pipelineName" + "/$pipelineID" + "/pipeline"
LogText -text "------------------------Test Pipeline Scheduled-----------------------"
LogText -text "Your pipeline should be running at below location.."
LogText -text "$finalURL"
LogText -text "----------------------------------------------------------------------"