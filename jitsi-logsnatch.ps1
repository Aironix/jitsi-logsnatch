param(
        [parameter(Mandatory = $false)][switch]$all
    )

#--- Variables ---
$LogFilePath = "/var/log/jitsi/jicofo.log"
$LogFilePath = "D:\jicofo.log"  #for testing purposes on windows client

$Global:Rooms = @()
$Global:LogFileContent = Get-Content -Path $LogFilePath

#--- Functions ---

Function Get-NumberOfParticipants {
    $LogLength = $Global:LogFileContent.Length
    $j = 0
    foreach($object in $Global:Rooms){
        if($object.RoomState -eq $true){
            $i = $object.OpenedOnLogLine
            $ParticipantCount = 0
            while ($i -lt $LogLength) {
                if(($Global:LogFileContent[$i] -like "*Member joined:*") -and ($object.RoomName -eq (Get-RoomNameFromLogLine $Global:LogFileContent[$i]))){
                    $ParticipantCount = $ParticipantCount + 1
                }
                if(($Global:LogFileContent[$i] -like "*Member left:*") -and ($object.RoomName -eq (Get-RoomNameFromLogLine $Global:LogFileContent[$i]))){
                    $ParticipantCount = $ParticipantCount - 1
                }
                $i++
            }
            $Global:Rooms[$j].ParticipantCount = $ParticipantCount
        }
        $j++
    }
}

Function Get-RoomNameFromLogLine {
    param(
        [parameter(Mandatory = $true)][string]$LogLine
    )
    $SplittedLine = $LogLine.Split("=").Split("@")
    return $SplittedLine[1]
}

Function Get-TimeOfLogLine {
    param(
        [parameter(Mandatory = $true)][string]$LogLine
    )
    $SplittedLine = $LogLine.Split(" ").Split(".")
    $Date = $SplittedLine[1] #Format yyyy-MM-dd
    $Time = $SplittedLine[2] #Format HH:mm:ss
    $combinedstring = $Date + "_" + $Time #Format yyyy-MM-dd_HH:mm:ss
    $DateTime = [DateTime]::ParseExact($combinedstring, 'yyyy-MM-dd_HH:mm:ss', $null)
    return $DateTime
}

Function Get-OpenedRooms {
    $i = 0
    foreach ($line in $Global:LogFileContent) {
        $i++
        if ($line -like "*Created new conference*") {
            $RoomState = $true
            $RoomName = Get-RoomNameFromLogLine -LogLine $line
            $StartTime = Get-TimeOfLogLine -LogLine $line

            $RoomObject = [PSCustomObject]@{
                RoomName         = $RoomName
                RoomState        = $RoomState
                StartTime        = $StartTime
                EndTime          = ""
                ParticipantCount = 0
                OpenedOnLogLine  = $i
                ClosedOnLogLine  = $null
            }

            $Global:Rooms += $RoomObject
        }
    }
}

Function Get-ClosedRooms {
    $LogLength = $Global:LogFileContent.Length
    $j = 0
    foreach ($object in $Global:Rooms) {
        $i = $object.OpenedOnLogLine
        while ($i -lt $LogLength) {
            if (($Global:LogFileContent[$i] -like "*JitsiMeetConferenceImpl.stop#428: Stopped*") -and ($object.RoomName -eq (Get-RoomNameFromLogLine $Global:LogFileContent[$i]))){
                $EndTime = Get-TimeOfLogLine -LogLine $Global:LogFileContent[$i]
                $RoomState = $false

                $Global:Rooms[$j].EndTime = $EndTime
                $Global:Rooms[$j].RoomState = $RoomState
                $Global:Rooms[$j].ClosedonLogLine = $i + 1
                break
            }
            $i++
        }
        $j++
    }
}

#--- Code --- 

Get-OpenedRooms
Get-ClosedRooms
Get-NumberOfParticipants

if(!($all)){
    $Global:Rooms | Where-Object {$_.RoomState -eq $true} | Select-Object RoomName, StartTime, ParticipantCount  | Format-Table
} else {
    $Global:Rooms | Select-Object RoomName, StartTime, EndTime, ParticipantCount | Format-Table
}
