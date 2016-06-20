﻿<#
.SYNOPSIS
    This script along with the Get-AllDiskInfo function (at the end) attempts to provide all disk information for the localhost
    in a way that ties Disk, Partition, and Volume information together ***in one output***.
.DESCRIPTION
    At first glance, it may seem that more recent PowerShell cmdlets (and even just diskpart) already fulfill this need. 
    However, all newer PowerShell cmdlets that I have explored fail to tie Disk, Partition, and Volume information
    together ***in the same output***

    This script/function also provides the ability to create hashtables and PSObjects based on Disk/Partition for easier
    extensibility.
    
    This script/function is compatible with ***all*** versions of PowerShell, since, ultimately, it is all based on diskpart output.

    Dot source the script to make the Get-AllDiskInfo available to you in your current shell.
    . .\Get-AllDiskInfo.ps1

.PARAMETER outputtype
    Use this parameter to specify if you want output to be an array of strings, hashes, or PSObjects
.PARAMETER disknum
    Use this parameter to indicate that you want the output to contain array elements related to a specific disk number. 
.INPUTS
    Text
.OUTPUTS
    An array of strings, or an array of hashes, or an array of PSObjects
    OR
    Specific elements from an array of strings, or and array of hashes, or an array of PSObjects 

.EXAMPLE
    Get-AllDiskInfo
    
    Get disk information for all disks on localhost as an array of strings.
    NOTE: Executing the function without any parameters defaults the "outputtype parameter to "strings"

    This is the same as:
    Get-AllDiskInfo -outputtype strings

.EXAMPLE
    Get-AllDiskInfo -disknum 0

    Get disk information for Disk 0 on localhost as an array of strings.
    
    This is the same as:
    Get-AllDiskInfo -outputtype strings -disknum 0

.EXAMPLE
    Get-AllDiskInfo -outputtype hashes -disknum 0
    
    Get disk information for Disk 0 on localhost as an array of hashes.

.EXAMPLE
    Get-AllDiskInfo -outputtype PSObjects -disknum 2
    
    Get disk information for Disk 2 on localhost as an array of PSObjects. 
     
.NOTES
    Author:         "My Name"
       
    Changelog:
        1.0         Initial Release

.LINK

#>

# Clear Existing Variables
<#
if ($sysvars -eq $null) {
    $sysvars = get-variable | Select-Object -ExpandProperty Name
}
function remove-uservars {
    get-variable | where {$sysvars -notcontains $_.Name -and $_.Name -ne "sysvars"} | remove-variable
}
remove-uservars
#>

####################################################
# BEGIN SETTING UP VARIABLES TO OUTPUT $EVERYTHING
####################################################

$disknumberarrayprep = "list disk" | diskpart | Select-String "Disk [0-9]" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$disknumberarray = foreach ($obj in $disknumberarrayprep) {
    $obj.ToString().Split(" ") | Select-Object -Index 1
}

$partitionnumberarray = foreach ($disknumber in $disknumberarray) {
    $partitionnumberarrayprep = "select disk $disknumber", "list partition" | diskpart | Select-String "Partition [0-9]" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    $partitionnumberarrayprep2 = foreach ($obj in $partitionnumberarrayprep) {
        $obj.ToString().Split(" ") | Select-Object -Index 1
    }
    $partitionnumberarrayprep2
}

$diskspartitionsandtypesarray = foreach ($disknumber in $disknumberarray) {
    $diskspartitionsandtypesarrayprep = "select disk $disknumber", "list partition" | diskpart | Select-String '(Partition [0-9]    )(\w{3,8})' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    foreach ($obj1 in $diskspartitionsandtypesarrayprep) {
        $obj2 = $obj1.Split(" ") | Select-Object -Index 5
        $obj3 = $obj1.Replace("   $obj2","Type=$obj2")
        "Disk $disknumber / $obj3"
    }
}

$disksandpartitionsarray = foreach ($disknumber in $disknumberarray) {
    $disksandpartitionsarrayprep = "select disk $disknumber", "list partition" | diskpart | Select-String '(Partition [0-9])' |`
    Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    foreach ($obj in $disksandpartitionsarrayprep) {
        "Disk $disknumber / $obj"
    }
}

$volumearrayprep = "list volume" | diskpart
$volumenumberarray = foreach ($obj1 in $volumearrayprep) {
    $obj2 = $obj1 | Select-String "Volume [0-9]" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = $obj2.Split(" ") | Select-Object -Index 1
        $obj3
    }
}

# Volume Letter Array Using WMI
#$volumeletterarray = gwmi win32_volume | Select-Object DriveLetter | Select-String "[A-Z]:" | Select-Object -ExpandProperty Matches |`
#Select-Object -ExpandProperty Value

# Volume Letter Array Using diskpart
$volumeletterarray = foreach ($obj1 in $volumearrayprep) {
    $obj2 = $obj1 | Select-String "Volume [0-9][\s]{2,12}[A-Z]" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = $obj2.Split(" ") | Select-Object -Index 6
        if ($obj3 -match "[A-Z]") {
            $obj3+":"
        }
    }
}

$volumeletterarraysanscolon = foreach ($obj1 in $volumeletterarray) {
    $obj1.Replace(":","")
}

# Volume Label Array Using WMI
$volumelabelarray = (gwmi win32_volume | Select-Object Label | Select-String '(Label=[\w]{1,32}[\s]{1,2}[\w]{1,32})|(Label=[\w]{1,32})' |`
Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value) -replace 'Label=',''

# Volume Label Array Using diskpart
<#
$volumelabelarray = foreach ($obj1 in $volumenumberarrayprep) {
    $obj2 = $obj1 | Select-String "Volume [0-9]     [A-Z]   [\w]{3,11}" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = $obj2.Split(" ") | Select-Object -Index 9
        $obj3
    }
}
#>

$everythingprep = foreach ($diskandpartition in $disksandpartitionsarray) {
    $disknumber = ($diskandpartition | Select-String "Disk [0-9]" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value).`
    Split(" ") | Select-Object -Index 1
    $partitionnumber = ($diskandpartition | Select-String "Partition [0-9]" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value).`
    Split(" ") | Select-Object -Index 1

    $obj1 = "select disk $disknumber", "select partition $partitionnumber", "detail partition" | diskpart
    $obj2 = $obj1 | Sort-Object | Get-Unique | Select-String "Volume [0-9]"
    "Disk $disknumber / Partition $partitionnumber : $obj2"
}

$everythingprep2 = foreach ($obj in $everythingprep) {
    $obj.Replace("* ","")
}

$everythingprep3 = foreach ($obj1 in $everythingprep2) {
    foreach ($obj2 in $diskspartitionsandtypesarray) {
        $obj3 = $obj2 | Select-String 'Disk [0-9] / Partition [0-9]' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
        if ($obj1 -like "*$obj3*") {
            $obj1.Replace("$obj3","$obj2")
        }
    }
}

$interim1 = foreach ($obj1 in $everythingprep3) {
    $obj1.IndexOf(":")
}
$interim2 = $interim1 | Sort-Object | Get-Unique
#$interim2objectcount = $interim2.count
#$interim2objectcountarray = for ($i = 0; $i -lt $interim2objectcount; $i++) {$i}

$everythingprep4 = foreach ($obj1 in $everythingprep3) {
    $obj2 = $obj1.IndexOf(":")
    if ($obj2 -eq 30) {
        $obj1.Replace(":","     :")
    }
    if ($obj2 -eq 31) {
        $obj1.Replace(":","    :")
    }
    if ($obj2 -eq 32) {
        $obj1.Replace(":","   :")
    }
    if ($obj2 -eq 33) {
        $obj1.Replace(":","  :")
    }
    if ($obj2 -eq 34) {
        $obj1.Replace(":"," :")
    }
    if ($obj2 -eq 35) {
        $obj1
    }
}

$everythingprep5 = foreach ($obj1 in $everythingprep4) {
    $obj2 = $obj1 | Select-String "Volume [0-9][\s]{2,5}[A-Z]" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = ($obj2.ToString() -replace '\s+',' ').Split(" ") | Select-Object -Last 1 | Select-Object -Index 0
    }
    if ($obj3 -ne $null) {
        $obj1.Replace("    $obj3 "," DriveLetter=$obj3")
    }
}

# This gets the rows that do NOT have a drive letter
$everythingprep6 = foreach ($obj1 in $everythingprep5) {
    $obj2 = $obj1 | Select-String "Volume [0-9][\s]{3,12}[\w]{3,32}" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = ($obj2.ToString() -replace '\s+',' ').Split(" ") | Select-Object -Last 1 | Select-Object -Index 0
    }
    if ($obj3 -ne $null) {
        $obj1.Replace(" $obj3 ","         Label=$obj3")
    }
}

# This gets the rows that DO have a drive letter
$everythingprep7 = foreach ($obj1 in $everythingprep6) {
    $obj2 = $obj1 | Select-String 'DriveLetter=[A-Z][\s]{1,4}[\w]{2,32}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = ($obj2.ToString() -replace '\s+',' ').Split(" ") | Select-Object -Index 1
    }
    if ($obj3 -ne $null) {
        $obj1.Replace(" $obj3"," Label=$obj3")
    }
}

# Add FS= to lines that contain Label=
$everythingprep8 = foreach ($obj1 in $everythingprep7) {
    $obj2 = $obj1 | Select-String 'Label=[\w\s]{2,32}[\s]{2,8}[\w]{4,8}[\s]{1,4}[\w]{3,11}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = ($obj2.ToString() -replace '\s+',' ').Split(" ") | Select-Object -Last 2 | Select-Object -Index 0
        $obj1.Replace(" $obj3"," FS=$obj3")
    }
    else {
        $obj1
    }
}

# Add FS= to Lines that contain DriveLetter= but not Label=
$everythingprep85 = foreach ($obj1 in $everythingprep8) {
    $obj2 = $obj1 | Select-String 'DriveLetter=[A-Z][\s]{5,16}[\w]{3,6}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = ($obj2.ToString() -replace '\s+',' ').Split(" ") | Select-Object -Last 1 | Select-Object -Index 0
        $obj1.Replace(" $obj3","       FS=$obj3")
    }
    else {
        $obj1
    }
}
# Add FS= to Lines that contain neither DriveLetter= nor Label=
$everythingprep86 = foreach ($obj1 in $everythingprep85) {
    $obj2 = $obj1 | Select-String '[\s]{5,25}[\w]{3,6}[\s]{1,5}Partition' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = ($obj2.ToString() -replace '\s+',' ').Split(" ") | Select-Object -Last 1 | Select-Object -Index 0
        $obj1.Replace(" $obj3","               FS=$obj3")
    }
    else {
        $obj1
    }
}

$everythingprep9 = foreach ($obj1 in $everythingprep86) {
    $obj2 = $obj1 | Select-String 'Partition[\s]{2,6}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj1.Replace("$obj2","Size=")
    }
    if (! ($obj2 -ne $null)) {
        $obj1
    }
}

$everythingprep10 = foreach ($obj1 in $everythingprep9) {
    $obj2 = $obj1 | Select-String 'Removable[\s]{2,6}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj1.Replace("$obj2","Size=")
    }
    if (! ($obj2 -ne $null)) {
        $obj1
    }
}

$everythingprep11 = foreach ($obj1 in $everythingprep10) {
    $obj2 = $obj1 | Select-String 'B[\s]{2,2}[\w]{3,7}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = $obj2.ToString().Split(" ") | Select-Object -Index 2
    }
    if (! ($obj1 -like "*$obj3*")) {
        $obj1
    }
    if ($obj1 -like "*$obj3*") {
        $obj1.Replace("$obj3","Status=$obj3")
    }
}

$everything = foreach ($obj1 in $everythingprep11) {
    $obj2 = $obj1 | Select-String 'Status=[\w]{3,7}[\s]{2,4}[\w]{3,7}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    if ($obj2 -ne $null) {
        $obj3 = $obj2.Split(" ") | Select-Object -Last 1
    }
    if (! ($obj1 -like "*$obj3*")) {
        $obj1
    }
    if ($obj1 -like "*$obj3*") {
        $obj1.Replace(" $obj3","Info=$obj3")
    }
}

####################################################
# END SETTING UP VARIABLES TO OUTPUT $EVERYTHING
####################################################

function ConvertTo-Scriptblock  {
<#
 Function to Convert a String into a Script Block
#>
	Param(
        [Parameter(
            Mandatory = $true,
            ParameterSetName = '',
            ValueFromPipeline = $true)]
            [string]$string 
        )
       $scriptBlock = [scriptblock]::Create($string)
       return $scriptBlock
}

#########################################################################
# BEGIN SETTING UP SCRIPTBLOCK FOR ARRAY OF HASHES AND ARRAY OF PSOBJECTS
#########################################################################

$NumberOfEverythingObjects = $everything.count
$NumberOfEverythingObjectsArray = for ($i = 0; $i -lt $NumberOfEverythingObjects; $i++) {$i}

$diskobjectarrayscriptblock = 
@"
`$DiskNumberValuePrep = `$obj1 | Select-String 'Disk [0-9]' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$DiskNumberValuePrep -ne `$null) {
    `$DiskNumberValue = `$DiskNumberValuePrep.Split(" ") | Select-Object -Index 1
}
else {
    `$DiskNumberValue = ""
}
    
`$PartitionNumberValuePrep = `$obj1 | Select-String 'Partition [0-9]' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$PartitionNumberValuePrep -ne `$null) {
    `$PartitionNumberValue = `$PartitionNumberValuePrep.Split(" ") | Select-Object -Index 1
}
else {
    `$PartitionNumberValue = ""
}

`$PartitionTypeValuePrep = `$obj1 | Select-String 'Type=[\w]{3,8}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$PartitionTypeValuePrep -ne `$null) {
    `$PartitionTypeValue = `$PartitionTypeValuePrep.Split("=") | Select-Object -Index 1
}
else {
    `$PartitionTypeValue = ""
}

`$VolumeNumberValuePrep = `$obj1 | Select-String 'Volume [0-9]' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$VolumeNumberValuePrep -ne `$null) {
    `$VolumeNumberValue = `$VolumeNumberValuePrep.Split(" ") | Select-Object -Index 1
}
else {
    `$VolumeNumberValue = ""
}

`$VolumeLetterValuePrep = `$obj1 | Select-String 'DriveLetter=[A-Z]' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$VolumeLetterValuePrep -ne `$null) {
    `$VolumeLetterValue = `$VolumeLetterValuePrep.Split("=") | Select-Object -Index 1
}
else {
    `$VolumeLetterValue = ""
}

`$VolumeLabelValuePrep = `$obj1 | Select-String 'Label=[\w]{3,11}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$VolumeLabelValuePrep -ne `$null) {
    `$VolumeLabelValue = `$VolumeLabelValuePrep.Split("=") | Select-Object -Index 1
}
else {
    `$VolumeLabelValue = ""
}

`$FileSystemValuePrep = `$obj1 | Select-String 'FS=[\w]{3,12}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$FileSystemValuePrep -ne `$null) {
    `$FileSystemValue = `$FileSystemValuePrep.Split("=") | Select-Object -Index 1
}
else {
    `$FileSystemValue = ""
}

`$PartitionSizeValuePrep = `$obj1 | Select-String 'Size=[\d]{1,5} [A-Z]{1,2}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$PartitionSizeValuePrep -ne `$null) {
    `$PartitionSizeValue = `$PartitionSizeValuePrep.Split("=") | Select-Object -Index 1
}
else {
    `$PartitionSizeValue = ""
}

`$PartitionStatusValuePrep = `$obj1 | Select-String 'Status=[\w]{3,7}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$PartitionStatusValuePrep -ne `$null) {
    `$PartitionStatusValue = `$PartitionStatusValuePrep.Split("=") | Select-Object -Index 1
}
else {
    `$PartitionStatusValue = ""
}

`$PartitionInfoValuePrep = `$obj1 | Select-String 'Info=[\w]{3,7}' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
if (`$PartitionInfoValuePrep -ne `$null) {
    `$PartitionInfoValue = `$PartitionInfoValuePrep.Split("=") | Select-Object -Index 1
}
else {
    `$PartitionInfoValue = ""
}

`$hash = @{            
    DiskNumber       = `$DiskNumberValue
    PartitionNumber  = `$PartitionNumberValue
    PartitionType    = `$PartitionTypeValue
    VolumeNumber     = `$VolumeNumberValue
    VolumeLetter     = `$VolumeLetterValue
    VolumeLabel      = `$VolumeLabelValue
    FileSystem       = `$FileSystemValue
    PartitionSize    = `$PartitionSizeValue
    PartitionStatus  = `$PartitionStatusValue
    PartitionInfo    = `$PartitionInfoValue
}
"@

#$scriptblockconverted = ConvertTo-Scriptblock $diskobjectarrayscriptblock

#########################################################################
# END SETTING UP SCRIPTBLOCK FOR ARRAY OF HASHES AND ARRAY OF PSOBJCTS
#########################################################################

####################################################
# BEGIN SETTING UP ARRAY OF HASHES
####################################################

$makescriptblockforhashes = "$diskobjectarrayscriptblock"+"`r`n"+"`$hash"
$scriptblockconvertedforhashes = ConvertTo-Scriptblock $makescriptblockforhashes

$DiskObjectArrayOfHashes = foreach ($obj1 in $everything) {
    &$scriptblockconvertedforhashes
}
#$DiskObjectArrayOfHashes
#$DiskObjectArrayOfHashes[0].GetEnumerator() | Sort -Property Value


####################################################
# END SETTING UP ARRAY OF HASHES
####################################################

####################################################
# BEGIN SETTING UP ARRAY OF PSOBJECTS
####################################################

$makescriptblockforPSObjects = "$diskobjectarrayscriptblock"+"`r`n"+"`$DiskObject = New-Object PSObject -Property `$hash"+"`r`n"+"`$DiskObject"
$scriptblockconvertedforPSObjects = ConvertTo-Scriptblock $makescriptblockforPSObjects

$DiskObjectArrayOfPSObjects = foreach ($obj1 in $everything) {
    &$scriptblockconvertedforPSObjects
}
#$DiskObjectArrayOfPSObjects
#$DiskObjectArrayOfPSObjects[0]

####################################################
# END SETTING UP ARRAY OF PSOBJECTS
####################################################

####################################################
# BEGIN ESTABLISH UNIVERSAL FUNCTION
####################################################

Function Get-AllDiskInfo {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False)]
        [string]$outputtype = "strings",

        [Parameter(Mandatory=$False)]
        $disknum = "null",

        [Parameter(Mandatory=$False)]
        $volume = "null",

        [Parameter(Mandatory=$False)]
        $label = "null"
    )

    Process 
    { 
        # Establish Error Checking
        if ("strings",“hashes”,"PSObjects" -NotContains $outputtype) { 
            Throw “$($outputtype) is not a valid outputtype! Please use 'hashes' or 'PSObjects' sans quotes” 
        }
        if ($disknum -ne "null") {
            if ($disknum -isnot [int]) { 
                Throw “$($disknum) is not a an integer. Please provide a number less than or equal to "+$disknumberarray.count
            } 
        }
        if ($disknum -ne "null") {
            if ($disknum -ge $disknumberarray.count) {
                Throw “$($disknum) is greater than "+($disknumberarray.count-1)+". Please provide a number less than or equal to "+$disknumberarray.count
            }
        }
        if ($volume -ne "null") {
            if ($volume -is [int]) {
                if ($volume -gt $volumenumberarray.count) {
                    Throw “Volume Number "+$volume+" is greater than "+$volumenumberarray.count+". Please provide a number less than or equal to "+$volumenumberarray.count
                }
            }
            else {
                if ($volumeletterarraysanscolon -notcontains $volume) {
                    Throw "Volume Letter "+$volume+" has not been found. Please verify that the volume letter exists according to diskpart."
                }
            }
        }
        if ($label -ne "null") {
            if ($volumelabelarray -notcontains $label) {
                Throw "Volume Label "+$label+" has not been found. Please verify that there is a volume labeled "+$label+" according to diskpart."
            }
        }

        # Begin Checking if certain combinations of Disk Number, Volume Number/Letter, and Volume Label are valid
        if ($disknum -ne "null" -and $label -ne "null") {
            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                if ($DiskObjectArrayOfPSObjects[$i].DiskNumber -eq $disknum -and $DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                    Write-Host "Combination of DiskNumber $disknum and VolumeLabel $label exists. Continuing..."
                }
                else {
                    Throw "A combination of DiskNumber $disknum and VolumeLabel $label does not exist."
                }
            }
        }
        if ($disknum -ne "null" -and $volume -ne "null") {
            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                if ($volume -is [int]) {
                    if ($DiskObjectArrayOfPSObjects[$i].DiskNumber -eq $disknum -and $DiskObjectArrayOfPSObjects[$i].VolumeNumber -eq $volume) {
                        Write-Host "Combination of DiskNumber $disknum and VolumeNumber $volume exists. Continuing..."
                    }
                    else {
                        Throw "A combination of DiskNumber $disknum and VolumeNumber $volume does not exist."
                    }
                }
                else {
                    if ($DiskObjectArrayOfPSObjects[$i].DiskNumber -eq $disknum -and $DiskObjectArrayOfPSObjects[$i].VolumeLetter -eq $volume) {
                        Write-Host "Combination of DiskNumber $disknum and VolumeLetter $volume exists. Continuing..."
                    }
                    else {
                        Throw "A combination of DiskNumber $disknum and VolumeLetter $volume does not exist."
                    }
                }
                
            }
        }
        if ($disknum -ne "null" -and $label -ne "null" -and $volume -ne "null") {
            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                if ($volume -is [int]) {
                    if ($DiskObjectArrayOfPSObjects[$i].DiskNumber -eq $disknum -and $DiskObjectArrayOfPSObjects[$i].VolumeNumber -eq $volume -and $DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                        Write-Host "Combination of DiskNumber $disknum, VolumeNumber $volume, and VolumeLabel $label exists. Continuing..."
                    }
                    else {
                        Throw "A combination of DiskNumber $disknum, VolumeNumber $volume, and VolumeLabel $label does not exist."
                    }
                }
                else {
                    if ($DiskObjectArrayOfPSObjects[$i].DiskNumber -eq $disknum -and $DiskObjectArrayOfPSObjects[$i].VolumeLetter -eq $volume -and $DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                        Write-Host "Combination of DiskNumber $disknum, VolumeLetter $volume, and VolumeLabel $label exists. Continuing..."
                    }
                    else {
                        Throw "A combination of DiskNumber $disknum, VolumeLetter $volume, and VolumeLabel $label does not exist."
                    }
                }
                
            }
        }
        if ($label -ne "null" -and $volume -ne "null") {
            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                if ($volume -is [int]) {
                    if ($DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label -and $DiskObjectArrayOfPSObjects[$i].VolumeNumber -eq $volume) {
                        Write-Host "Combination of VolumeLabel $label and VolumeNumber $volume exists. Continuing..."
                    }
                    else {
                        Throw "A combination of VolumeLabel $label and VolumeNumber $volume does not exist."
                    }
                }
                else {
                    if ($DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label -and $DiskObjectArrayOfPSObjects[$i].VolumeLetter -eq $volume) {
                        Write-Host "Combination of VolumeLabel $label and VolumeLetter $volume exists. Continuing..."
                    }
                    else {
                        Throw "A combination of VolumeLabel $label and VolumeLetter $volume does not exist."
                    }
                }
                
            }
        }

        # Error checking passed, so start doing stuff
        if ($outputtype -eq "strings") {
            if ($disknum -eq "null") {
                if ($volume -eq "null") {
                    if ($label -eq "null") {
                        $everything
                    }
                    else {
                        foreach ($obj1 in $everything) {
                            $obj2 = $obj1 | Select-String "Label=$label"
                            if ($obj2 -ne $null) {
                                $obj1
                            }
                        }
                    }
                }
                else {
                    if ($volume -is [int]) {
                        if ($label -eq "null") {
                            foreach ($obj1 in $everything) {
                                $obj2 = $obj1 | Select-String "Volume $volume"
                                if ($obj2 -ne $null) {
                                    $obj1
                                }
                            }
                        }
                        else {
                            foreach ($obj1 in $everything) {
                                $obj2 = $obj1 | Select-String "Label=$label"
                                if ($obj2 -ne $null) {
                                    $obj1
                                }
                            }
                        }
                    }
                    else {
                        if ($label -eq "null") {
                            foreach ($obj1 in $everything) {
                                $obj2 = $obj1 | Select-String "DriveLetter=$volume"
                                if ($obj2 -ne $null) {
                                    $obj1
                                }
                            }
                        }
                        else {
                            foreach ($obj1 in $everything) {
                                $obj2 = $obj1 | Select-String "Label=$label"
                                if ($obj2 -ne $null) {
                                    $obj1
                                }
                            }
                        }
                    }
                }
            }
            else {
                if ($volume -eq "null") {
                    if ($label -eq "null") {
                        foreach ($obj1 in $everything) {
                            $obj2 = $obj1 | Select-String "Disk $disknum" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
                            if ($obj2 -ne $null) {
                                $obj1
                            }
                        }
                    }
                    else {
                        foreach ($obj1 in $everything) {
                            $obj2 = $obj1 | Select-String "Label=$label"
                            if ($obj2 -ne $null) {
                                $obj1
                            }
                        }
                    }
                }
                else {
                    if ($volume -is [int]) {
                        if ($label -eq "null") {
                            foreach ($obj1 in $everything) {
                                $obj2 = $obj1 | Select-String "Volume $volume"
                                if ($obj2 -ne $null) {
                                    $obj1
                                }
                            }
                        }
                        else {
                            foreach ($obj1 in $everything) {
                                $obj2 = $obj1 | Select-String "Label=$label"
                                if ($obj2 -ne $null) {
                                    $obj1
                                }
                            }
                        }
                    }
                    else {
                        if ($label -eq "null") {
                            foreach ($obj1 in $everything) {
                                $obj2 = $obj1 | Select-String "DriveLetter=$volume"
                                if ($obj2 -ne $null) {
                                    $obj1
                                }
                            }
                        }
                        else {
                            foreach ($obj1 in $everything) {
                                $obj2 = $obj1 | Select-String "Label=$label"
                                if ($obj2 -ne $null) {
                                    $obj1
                                }
                            }
                        }
                    }
                }
            }
                
        }
        if ($outputtype -eq "hashes") {
            if ($disknum -eq "null") {
                if ($volume -eq "null") {
                    if ($label -eq "null") {
                        for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                            Write-Host ""
                            Write-Host ""
                            Write-Host "Table $i"
                            Write-Host "Result of `$DiskObjectArrayOfHashes[$i]"
                            Write-Host ""
                            $DiskObjectArrayOfHashes[$i]
                        }
                    }
                    else {
                        for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                            if ($DiskObjectArrayOfHashes[$i].Item("VolumeLabel") -eq $label) {
                                $DiskObjectArrayOfHashes[$i]
                            }
                        }
                    }
                }
                else {
                    if ($volume -is [int]) {
                        if ($label -eq "null") {
                            for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                                if ($DiskObjectArrayOfHashes[$i].Item("VolumeNumber") -eq $volume) {
                                    $DiskObjectArrayOfHashes[$i]
                                }
                            }
                        }
                        else {
                            for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                                if ($DiskObjectArrayOfHashes[$i].Item("VolumeLabel") -eq $label) {
                                    $DiskObjectArrayOfHashes[$i]
                                }
                            }
                        }
                    }
                    else {
                        if ($label -eq "null") {
                            for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                                if ($DiskObjectArrayOfHashes[$i].Item("VolumeLetter") -eq $volume) {
                                    $DiskObjectArrayOfHashes[$i]
                                }
                            }
                        }
                        else {
                            for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                                if ($DiskObjectArrayOfHashes[$i].Item("VolumeLabel") -eq $label) {
                                    $DiskObjectArrayOfHashes[$i]
                                }
                            }
                        }
                    }
                }
            }
            else {
                if ($volume -eq "null") {
                    if ($label -eq "null") {
                        for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                            if ($DiskObjectArrayOfHashes[$i].Item("DiskNumber") -eq $disknum) {
                                Write-Host ""
                                Write-Host ""
                                Write-Host "Table $i"
                                Write-Host "Result of `$DiskObjectArrayOfHashes[$i]"
                                Write-Host ""
                                $DiskObjectArrayOfHashes[$i]
                            }
                        }
                    }
                    else {
                        for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                            if ($DiskObjectArrayOfHashes[$i].Item("VolumeLabel") -eq $label) {
                                $DiskObjectArrayOfHashes[$i]
                            }
                        }
                    }
                }
                else {
                    if ($volume -is [int]) {
                        if ($label -eq "null") {
                            for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                                if ($DiskObjectArrayOfHashes[$i].Item("VolumeNumber") -eq $volume) {
                                    $DiskObjectArrayOfHashes[$i]
                                }
                            }
                        }
                        else {
                            for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                                if ($DiskObjectArrayOfHashes[$i].Item("VolumeLabel") -eq $label) {
                                    $DiskObjectArrayOfHashes[$i]
                                }
                            }
                        }
                    }
                    else {
                        if ($label -eq "null") {
                            for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                                if ($DiskObjectArrayOfHashes[$i].Item("VolumeLetter") -eq $volume) {
                                    $DiskObjectArrayOfHashes[$i]
                                }
                            }
                        }
                        else {
                            for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
                                if ($DiskObjectArrayOfHashes[$i].Item("VolumeLabel") -eq $label) {
                                    $DiskObjectArrayOfHashes[$i]
                                }
                            }
                        }
                    }
                }
            }
        }
        if ($outputtype -eq "PSObjects") {
            if ($disknum -eq "null") {
                if ($volume -eq "null") {
                    if ($label -eq "null") {
                        for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                            Write-Host ""
                            Write-Host ""
                            Write-Host "Object $i"
                            Write-Host "Result of `$DiskObjectArrayOfPSObjects[$i]"
                            Write-Host ""
                            $DiskObjectArrayOfPSObjects[$i]
                        }
                    }
                    else {
                        for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                            if ($DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                                $DiskObjectArrayOfPSObjects[$i]
                            }
                        }
                    }
                }
                else {
                    if ($volume -is [int]) {
                        if ($label -eq "null") {
                            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                                if ($DiskObjectArrayOfPSObjects[$i].VolumeNumber -eq $volume) {
                                    $DiskObjectArrayOfPSObjects[$i]
                                }
                            }
                        }
                        else {
                            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                                if ($DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                                    $DiskObjectArrayOfPSObjects[$i]
                                }
                            }
                        }
                    }
                    else {
                        if ($label -eq "null") {
                            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                                if ($DiskObjectArrayOfPSObjects[$i].VolumeLetter -eq $volume) {
                                    $DiskObjectArrayOfPSObjects[$i]
                                }
                            }
                        }
                        else {
                            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                                if ($DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                                    $DiskObjectArrayOfPSObjects[$i]
                                }
                            }
                        }
                    }
                }
            }
            else {
                if ($volume -eq "null") {
                    if ($label -eq "null") {
                        for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                            if ($DiskObjectArrayOfPSObjects[$i].DiskNumber -eq $disknum) {
                                $DiskObjectArrayOfPSObjects[$i]
                            }
                        }
                    }
                    else {
                        for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                            if ($DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                                $DiskObjectArrayOfPSObjects[$i]
                            }
                        }
                    }
                }
                else {
                    if ($volume -is [int]) {
                        if ($label -eq "null") {
                            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                                if ($DiskObjectArrayOfPSObjects[$i].VolumeNumber -eq $volume) {
                                    $DiskObjectArrayOfPSObjects[$i]
                                }
                            }
                        }
                        else {
                            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                                if ($DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                                    $DiskObjectArrayOfPSObjects[$i]
                                }
                            }
                        }
                    }
                    else {
                        if ($label -eq "null") {
                            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                                if ($DiskObjectArrayOfPSObjects[$i].VolumeLetter -eq $volume) {
                                    $DiskObjectArrayOfPSObjects[$i]
                                }
                            }
                        }
                        else {
                            for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
                                if ($DiskObjectArrayOfPSObjects[$i].VolumeLabel -eq $label) {
                                    $DiskObjectArrayOfPSObjects[$i]
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

####################################################
# END ESTABLISH UNIVERSAL FUNCTION
####################################################

####################################################
# BEGIN ARCHIVE
####################################################

<#
Function Get-SpecificDiskInfo($disknum) {
    foreach ($obj1 in $everything) {
        $obj2 = $obj1 | Select-String "Disk $disknum" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
        if ($obj2 -ne $null) {
            $obj1
        }
    }
}

Function Get-AllDiskInfoAsHashTables {
    for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
        Write-Host ""
        Write-Host ""
        Write-Host "Table $i"
        Write-Host "Result of `$DiskObjectArrayOfHashes[$i]"
        Write-Host ""
        $DiskObjectArrayOfHashes[$i]
    }
}

Function Get-AllDiskInfoAsHashTablesSpecificDisk($disknum) {
    for ($i = 0; $i -lt $DiskObjectArrayOfHashes.Count; $i++) {
        $obj2 = $DiskObjectArrayOfHashes[$i].Item("DiskNumber")
        if ($disknum -eq $obj2) {
            Write-Host ""
            Write-Host ""
            Write-Host "Table $i"
            Write-Host "Result of `$DiskObjectArrayOfHashes[$i]"
            Write-Host ""
            $DiskObjectArrayOfHashes[$i]
        }
    }
}

Function Get-AllDiskInfoAsPSObjects {
    for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
        Write-Host ""
        Write-Host ""
        Write-Host "Object $i"
        Write-Host "Result of `$DiskObjectArrayOfPSObjects[$i]"
        Write-Host ""
        $DiskObjectArrayOfPSObjects[$i]
    }
}

Function Get-AllDiskInfoAsPSObjectsSpecificDisk($disknum) {
    for ($i = 0; $i -lt $DiskObjectArrayOfPSObjects.Count; $i++) {
        $obj2 = $DiskObjectArrayOfPSObjects[$i].DiskNumber
        if ($obj2 -eq $disknum) {
            Write-Host ""
            Write-Host "Object $i"
            Write-Host ""
            $DiskObjectArrayOfPSObjects[$i]
        }
    }
}
#>

####################################################
# END ARCHIVE
####################################################