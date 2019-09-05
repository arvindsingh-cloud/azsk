#using namespace Microsoft.Azure.Commands.AppService.Models
Set-StrictMode -Version Latest
class DBForPostgreSQL: AzSVTBase
{
  hidden [PSObject] $ResourceObject;
   


    DBForPostgreSQL([string] $subscriptionId, [SVTResource] $svtResource):
        Base($subscriptionId, $svtResource)
    {
		  $this.GetResourceObject();
    }

    hidden [PSObject] GetResourceObject()
    {
      if (-not $this.ResourceObject) {
        $this.ResourceObject = Get-AzResource -ResourceId $this.ResourceId
        if(-not $this.ResourceObject)
        {
            throw ([SuppressedException]::new(("Resource '{0}' not found under Resource Group '{1}'" -f ($this.ResourceContext.ResourceName), ($this.ResourceContext.ResourceGroupName)), [SuppressedExceptionType]::InvalidOperation))
        }
      }

      return $this.ResourceObject;
    }

    hidden [ControlResult] CheckPostgreSQLSSLConnection([ControlResult] $controlResult)
    {
      
      #Fetching ssl Object
      $ssl_option = $this.ResourceObject.properties.sslEnforcement
      #checking ssl is enabled or disabled
      if($ssl_option -eq 'Enabled')
      {
        $controlResult.AddMessage([VerificationResult]::Passed, "SSL enforcement is enabled");
      }
      else 
      {
        $controlResult.AddMessage([VerificationResult]::Failed, "SSL enforcement is disabled");
      }
      #return
      return $controlResult
    }

    hidden [ControlResult] CheckPostgreSQLFirewallAccessAzureService([ControlResult] $controlResult)
    {
     try
       {
          $uri= "https://management.azure.com/subscriptions/$($this.SubscriptionContext.SubscriptionId)/resourceGroups/$($this.ResourceContext.ResourceGroupName)/providers/Microsoft.DBforPostgreSQL/servers/$($this.ResourceObject.ResourceName)/firewallRules?api-version=2017-12-01"
          
          $firewallDtls=[WebRequestHelper]::InvokeGetWebRequest($uri);
          if(($firewallDtls | Measure-Object ).Count -gt 0)
            {
              $firewallDtls = $firewallDtls | Where-Object { $firewallDtls.name -eq "AllowAllWindowsAzureIps" }
              if(($firewallDtls | Measure-Object ).Count -gt 0)
			          {
				          $controlResult.AddMessage([VerificationResult]::Verify,
                                            [MessageData]::new("Azure services are allowed to access the server ["+ $this.ResourceContext.ResourceName +"]"));
                }	
              else
                {
                  $controlResult.AddMessage([VerificationResult]::Passed, [MessageData]::new("Azure services are not allowed to access the server ["+ $this.ResourceContext.ResourceName +"]"));
                }
            }
          else
            {
              $controlResult.AddMessage([VerificationResult]::Passed, "No custom firewall rules found.");
            }
          }
        catch
          {
            Write-Output "No post gre server founds"
          }
      #return
      return $controlResult
    }



    hidden [ControlResult] CheckPSQLServerVnetRules([ControlResult] $controlResult)
    {
      $ResourceAppIdURI = [WebRequestHelper]::GetResourceManagerUrl()	
      $uri=[system.string]::Format($ResourceAppIdURI+"/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.DBforPostgreSQL/servers/{2}/virtualNetworkRules?api-version=2017-12-01",$this.SubscriptionContext.SubscriptionId,$this.ResourceContext.ResourceGroupName,$this.ResourceContext.ResourceName)      

      try
      {
        $response = [WebRequestHelper]::InvokeGetWebRequest($uri);
      }
      catch
      {
        $controlResult.AddMessage([VerificationResult]::Manual, "Add message.");
      }

      return $controlResult
    }


}
