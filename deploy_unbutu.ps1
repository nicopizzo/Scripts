$plinkDir = "C:\Program Files (x86)\PuTTY"
$bin = "D:\Projects\RasPiApi\bin\Debug\netcoreapp2.1\publish"
$folderName = "WebApi"

$linuxHost = ""
$linuxUser = ""
$linuxPw = ""
$linuxDir = "/usr/transfer/"

cd $plinkDir
echo y | ./plink $linuxUser@$linuxHost -pw $linuxPw "exit"

#find and kill dotnet process
$output = ./plink.exe $linuxUser@$linuxHost -pw $linuxPw ("lsof -i:5000")
$output = $output -split "`n"
$dotnet = ($output | Select-String -Pattern 'dotnet')
if($dotnet.Count -gt 0){
    Write-Host "Found dotnet running..."
    $rpid = $dotnet[0] -split " "
    $rpid = $rpid[2]
    ./plink.exe $linuxUser@$linuxHost -pw $linuxPw ("kill -9 $rpid")
    Write-Host "Killed dotnet process."
}

# clear directory
Write-Host "Clearing Project Directory..."
./plink.exe $linuxUser@$linuxHost -pw $linuxPw ("cd $linuxDir;rm -R $folderName")

# transfer files 
Write-Host "Transfering Project..."
./pscp.exe -r -pw $linuxPw $bin $linuxUser@${linuxHost}:${linuxDir} 

# rename and start application
Write-Host "Starting Service..."
./plink.exe $linuxUser@$linuxHost -pw $linuxPw ("cd $linuxDir;mv publish/ $folderName")

$jbFunctions = {
    param($plinkD, $user, $pass, $hostnm, $ldir, $fname)
    cd $plinkD
    ./plink.exe $user@$hostnm -pw $pass ("dotnet $ldir$fname/RasPiApi.dll")
}

$jb = Start-Job -ScriptBlock $jbFunctions -ArgumentList $plinkDir, $linuxUser,$linuxPw,$linuxHost, $linuxDir, $folderName

while($jb.HasMoreData) {
    Receive-Job $jb -OutVariable output | 
    ForEach-Object { 
        if ($_ -match "Application started.") {
            Write-Host "Service has started!"
            break
        }
    }
}

if ($jb.Status -eq 'Complete') { Remove-Job $jb }
exit
