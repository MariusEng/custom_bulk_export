Clear-Host

$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path

if(!(Test-Path -Path "$ScriptPath\export_list.xml"))
{
    Write-Host "Yikes! export_list file not found!" -ForegroundColor Red
    Write-Host "Make sure export_list.xml exists!" -ForegroundColor Red
    return
}
[xml]$Config = Get-Content -Path "$ScriptPath\export_list.xml"
$OutputPath = $Config.xml.OutputPath
$Debug = $Config.xml.Debug
$ConnectionString = ""
$TimeStamp = (Get-Date).ToString("yyMMdd")
$OutputPath = $OutputPath+$TimeStamp
if(!(Test-Path -Path $OutputPath))
{
    Write-Host "Export directory not found!" -ForegroundColor Red
    New-Item -Path $OutputPath -ItemType Directory | Out-Null
    Write-Host "Created directory: $OutputPath"
    # Exit
}

foreach ($company in $Config.xml.Companies.Company)
{
    $CompanyName = $company.name
    $CompanyId = $company.companyid

    Write-Host "Create log file: $CompanyName.Control.$TimeStamp.txt"
    #Create Logfile.

    foreach ($table in $Config.xml.tables.table)
    {
        $Server =  $table.server
        $Database = $table.database 
        $TableName = $table.name
        $TimeStamp = (Get-Date).ToString("yyMMdd")
        $ExportDirectory = $OutputPath+"\"+$table.service
        $TableName = $CompanyName+"."+$CompanyId+"."+$TableName+"."+$TimeStamp
        $LogFileName = "$ExportDirectory\$CompanyName.Control.$TimeStamp.txt"
        $ConnectionString = "Server=$Server;Initial Catalog=$Database;Persist Security Info=True;MultipleActiveResultSets=False;Trusted_Connection=True;"

        #Create directory for output!
        if($Debug -eq 1)
        {
            Write-Host $table.query
            Write-Host $ConnectionString
            Write-Host $ExportDirectory
            Write-Host $TableName
            Write-Host $LogFileName
        }
        if(!(Test-Path -Path $ExportDirectory))
        {   New-Item -Path $ExportDirectory -ItemType Directory | Out-Null}
        Write-Host "Exporting $CompanyName ($CompanyId): $TableName from $Database @ $Server"

        if(!(Test-Path -Path $LogFileName))
        {
            if($Debug -eq 1) { Write-Host "Create control file" }
            Set-Content -Path $LogFileName -Value "Exporting $CompanyName ($CompanyId): $TableName from $Database @ $Server"
        }
        else
        {
            if($Debug -eq 1) { Write-Host "Create control file" }
            Add-Content -Path $LogFileName -Value "Exporting $CompanyName ($CompanyId): $TableName from $Database @ $Server"
        }
      
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $SqlConnection.ConnectionString = $ConnectionString
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandText = $table.query
        $SqlCmd.Connection = $SqlConnection

        $SqlCmd.Parameters.AddWithValue('@companyid', $CompanyId) | Out-Null    

        if($Debug -eq 0)
        {
            $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            $SqlAdapter.SelectCommand = $SqlCmd 
            $DataSet = New-Object System.Data.DataSet
            try 
            {
                $SqlAdapter.Fill($DataSet) | Out-Null
                $DataSet.Tables[0] | Export-Csv -Path "$ExportDirectory\$TableName.csv" -NoTypeInformation -Delimiter "|" -UseQuotes Never
                $NumberOfRows = $DataSet.Tables[0].Rows.Count
            }
            catch
            {
                Write-Warning $_
                $NumberOfRows = 0
                New-Item -Path "$ExportDirectory\$TableName.csv" -ItemType File | Out-Null
            }
        }            
        Write-Host "Created $ExportDirectory\$TableName.csv with $NumberOfRows rows." -ForegroundColor Green
        Add-Content -Path $LogFileName -Value "Created $TableName.csv with $NumberOfRows rows." 
        $NumberOfRows = $null
        $SqlConnection.Close() 
    }
}   