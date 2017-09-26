workflow ResumeAzureSQLDataWarehouse {
    Param(
        $ConnectionName = "AzureRunAsConnection",
        [string]$ServerName,
        [string]$DWName,
        [int]$RetryCount = 5,
        [int]$RetryTime = 15  
    )

    $AutomationConnection = Get-AutomationConnection -Name $ConnectionName
    $null = Add-AzureRmAccount -ServicePrincipal -TenantId $AutomationConnection.TenantId -ApplicationId $AutomationConnection.ApplicationId -CertificateThumbprint $AutomationConnection.CertificateThumbprint
    $DWDetail = (Get-AzureRmResource | Where-Object {$_.Kind -like "*datawarehouse*" -and $_.Name -like "*/$DWName"}).ResourceId.Split("/")
    $cRetry = 0
    #Ensure that the ADW is Paused. Wait to ensure that if it is transitioning, the proper action is taken
    if ((Get-AzureRmSqlDatabase -ResourceGroup $DWDetail[4] -ServerName $DWDetail[8] -DatabaseName $DWDetail[10]).Status -ne "Online") {
        do {
            if ($cRetry -ne 0) {Start-Sleep -Seconds $RetryTime}
            $DWStatus = (Get-AzureRmSqlDatabase -ResourceGroup $DWDetail[4] -ServerName $DWDetail[8] -DatabaseName $DWDetail[10]).Status
            $cRetry++
        } while ($DWStatus -ne "Paused" -and $cRetry -le $RetryCount)
        if ($DWStatus -eq "Paused") {
            Get-AzureRmSqlDatabase -ResourceGroup $DWDetail[4] -ServerName $ServerName.Split(".")[0] -DatabaseName $DWDetail[10] | Resume-AzureRmSqlDatabase
        }
        $cRetry = 0
        #Now lets wait to ensure that the ADW has come online before completing
        do {
            if ($cRetry -ne 0) {Start-Sleep -Seconds $RetryTime}
            $DWStatus = (Get-AzureRmSqlDatabase -ResourceGroup $DWDetail[4] -ServerName $DWDetail[8] -DatabaseName $DWDetail[10]).Status
            $cRetry++
        } while ($DWStatus -ne "Online" -and $cRetry -le $RetryCount)
        if ($DWStatus -ne "Online") {
            Write-Error "Resume operation submitted. Operation did not complete timely."
        }
    }
}