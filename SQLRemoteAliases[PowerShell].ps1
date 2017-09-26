<#
 .SYNOPSIS
    SQL Server Alias Configuration on Remote Machines.
 .DESCRIPTION
    With the tool "CliConfg.exe" you can create local SQL Server Aliase.
    This is helpfull e.g. if you have a third party application which don't support instance names or
    if you want to force that connections are established over a dedicated network adapter or to use a specified protocoll.
    Or in a failover case to connect to a different SQL Server instance then specified in connection string;
    means you add an alias with the old SQL Server name pointing to the new server.
    But this configuration you have to do on each client and that could be a lot of time consuming work for you.
    With this PowerShell script you can read, edit or delete SQL Server Alias configuration on several remote machines in a batch.
 .NOTES
    Author  : CHE Jan Veenstra
    Requires: PowerShell Version 1.0
              Read/Write permissions for the Registry on the machines.
#>


# Please modify the variable values below for your requirement (see remarks).

param (
# Parameter Action: 0 = read reg value,
#                   1 = add/update value,
#                   2 = delete value.
[int]$action   = 0,


# List of machines.
[Array] $servers = @("CHECSQ4TEST" `
                   , "CHECSQ1A" `
                   , "CHECSQ1B" `
                   , "CHECSQ3A" `
                   , "CHECSQ3B" `
                   , "CHECSQ3C"), 

# List of operating system types.
[Array] $ostypes = @("32 bit" `
                   , "64 bit"),


# List of SQL Server aliases.
[Array] $aliases = @("SQLSIS" `
                   , "SQLSL" `
                   , "SQLMW" `
                   , "SQLBI" `
                   , "SQLLYNC" `
                   , "SQLAPPS")
)

# Fix constant values; don't modify.
[string]$hive  = "LocalMachine"

foreach($srv in $servers)
{    
    try
    {
        Write-Output "- Actions on machine $srv -";
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]$hive, $srv);
        
        foreach($os in $ostypes)
        {
            # Set Registry location for the SQL Alias locations depending of type of operating system
            if ($os -eq '32 bit')
            {    $key   = "SOFTWARE\\Microsoft\\MSSQLServer\\Client\\ConnectTo";    }
            else
            {    $key   = "SOFTWARE\\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo";    }

            # Open subkey depending of action in read or write mode.
            if ($action -eq 0)
            {    $subKey = $reg.OpenSubKey($key, $false);   }
            else
            {    $subKey = $reg.OpenSubKey($key, $true);   }

            if(!$subKey)
            {
                Write-Output "Key 'ConnectTo' for $os not found on machine $srv";
                
                if ($action -ne 0) 
                {   if ($os -eq '32 bit') {    
                        $key   = "SOFTWARE\\Microsoft\\MSSQLServer\\Client";    
                    }
                    else {
                        $key   = "SOFTWARE\\Wow6432Node\Microsoft\MSSQLServer\Client";    
                    }
                    try {
                        $subKey = $reg.OpenSubKey($key, $true);
                        $subkey.CreateSubKey('ConnectTo') | Out-Null
                    }
                    catch {
                        Write-Output "Key $key not found on machine $srv."
                        throw $_                    
                        Continue;
                    }
                    Write-Output "Key 'ConnectTo' for $os on machine $srv created"
                    $subKey = $reg.OpenSubKey("$key\ConnectTo", $true);
                }
                else
                {    Continue; }
            }

            try
            {
                foreach($name in $aliases)
                {
                    switch($name)
                    {
                        'SQLSIS'
                        { $value = "DBMSSOCN,CHECSQCL02";}

                        'SQLSL'
                        { $value = "DBMSSOCN,CHECSL02";}

                        'SQLMW'
                        { $value = "DBMSSOCN,CHECSQCL05\instance4";}

                        'SQLBI'
                        { $value = "DBMSSOCN,CHECSQCL07";}

                        'SQLLYNC'
                        { $value = "DBMSSOCN,CHECSQCL12\instance6";}

                        'SQLAPPS'
                        { $value = "DBMSSOCN,CHECSQCL10\instance4";}

                    }

                    $res = $subKey.GetValue($name);
                    switch ($action)
                    {
                        0 # Read reg key and prompt result.
                        {
                            if(!$res)
                            {   Write-Output "Value $name for $os doesn't exists";   }
                            else
                            {   Write-Output "Value $name for $os = $res";   }
                        }

                        1 # Add / edit alias.
                        {
                            $subKey.SetValue($name, $value);
                            if(!$res)
                            {    Write-Output "Value $name for $os added";   }
                            else
                            {   Write-Output "Value $name for $os updated";   }
                        }
                            
                        2 # Delete value.
                        {
                            if(!$res)
                            {   Write-Output "Nothing to delete";   }
                            else
                            {
                                $subKey.DeleteValue($name, $true);
                                Write-Output "Value $name for $os successfully deleted";
                            }
                        }
                            
                        default
                       {   Write-Output "Unkown action.";   }
                   }
                }
            }
            catch
            {
                Write-Output ($_.Exception.Message);
            }
        }
    }
    catch
    {
         Write-Output ("Error on " + $srv + ": " + $_.Exception.Message);
    }

    $reg.Close();   
}
