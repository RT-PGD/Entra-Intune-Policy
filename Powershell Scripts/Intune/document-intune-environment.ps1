<#
.SYNOPSIS
  Documents Intune environment into a Word document
.DESCRIPTION
Documents Intune environment into a Word document
Can be automated by setting $automated to "yes" and setting the variables below
Automated uploads documentation to github
.PARAMETER Path
    The path to the .
.PARAMETER LiteralPath
    Specifies a path to one or more locations. Unlike Path, the value of 
    LiteralPath is used exactly as it is typed. No characters are interpreted 
    as wildcards. If the path includes escape characters, enclose it in single
    quotation marks. Single quotation marks tell Windows PowerShell not to 
    interpret any characters as escape sequences.
.INPUTS
None
.OUTPUTS
Creates a log file in %Temp%
.NOTES
  Version:        1.0.0
  Author:         Andrew Taylor
  WWW:            andrewstaylor.com
  Creation Date:  22/12/2022
  Purpose/Change: Initial script development
 
.EXAMPLE
N/A
#>

<#PSScriptInfo
.VERSION 1.0.0
.GUID 4a4e0dc0-98d4-45f3-a82c-547a8ae618c2
.AUTHOR AndrewTaylor
.COMPANYNAME 
.COPYRIGHT GPL
.TAGS intune endpoint MEM environment
.LICENSEURI https://github.com/andrew-s-taylor/public/blob/main/LICENSE
.PROJECTURI https://github.com/andrew-s-taylor/public
.ICONURI 
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

##################################################################################################################################
#################                                                  PARAMS                                        #################
##################################################################################################################################

[cmdletbinding()]
    
param
(
    [string]$github #Set Github to Yes to upload output to a repo
    ,  
    [string]$reponame #Reponame is the github repo
    , 
    [string]$ownername #Ownername is the github account
    , 
    [string]$token #Token is the github token
    )


##################################################################################################################################
#################                                                  INITIALIZATION                                #################
##################################################################################################################################
$ErrorActionPreference = "Continue"
##Start Logging to %TEMP%\intune-documentation.log
$date = get-date -format yyyyMMddTHHmmssffff
Start-Transcript -Path $env:TEMP\intune-documentation-$date.log

#Install MS Graph if not available


Write-Host "Installing Microsoft Graph modules if required (current user scope)"

#Install MS Graph if not available
#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication) {
    Write-Host "Microsoft Graph Authentication Already Installed"
} 
else {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force 
        Write-Host "Microsoft Graph Authentication Installed"
}

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name microsoft.graph.devices.corporatemanagement ) {
    Write-Host "Microsoft Graph Corporate Management Already Installed"
} 
else {
        Install-Module -Name microsoft.graph.devices.corporatemanagement  -Scope CurrentUser -Repository PSGallery -Force 
        Write-Host "Microsoft Graph Corporate Management Installed"
    }

    if (Get-Module -ListAvailable -Name Microsoft.Graph.Groups) {
        Write-Host "Microsoft Graph Groups Already Installed "
    } 
    else {
            Install-Module -Name Microsoft.Graph.Groups -Scope CurrentUser -Repository PSGallery -Force 
            Write-Host "Microsoft Graph Groups Installed"
    }
    
    #Install MS Graph if not available
    if (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement) {
        Write-Host "Microsoft Graph DeviceManagement Already Installed"
    } 
    else {
            Install-Module -Name Microsoft.Graph.DeviceManagement -Scope CurrentUser -Repository PSGallery -Force 
            Write-Host "Microsoft Graph DeviceManagement Installed"
    }

    #Install MS Graph if not available
    if (Get-Module -ListAvailable -Name Microsoft.Graph.identity.signins) {
        Write-Host "Microsoft Graph Identity SignIns Already Installed"
    } 
    else {
            Install-Module -Name Microsoft.Graph.Identity.SignIns -Scope CurrentUser -Repository PSGallery -Force 
            Write-Host "Microsoft Graph Identity SignIns Installed"
    }


# Load the Graph module
Import-Module microsoft.graph.authentication
import-module Microsoft.Graph.Identity.SignIns
import-module Microsoft.Graph.DeviceManagement
import-module microsoft.Graph.Groups
import-module microsoft.graph.devices.corporatemanagement
Function Connect-ToGraph {
    <#
.SYNOPSIS
Authenticates to the Graph API via the Microsoft.Graph.Authentication module.
 
.DESCRIPTION
The Connect-ToGraph cmdlet is a wrapper cmdlet that helps authenticate to the Intune Graph API using the Microsoft.Graph.Authentication module. It leverages an Azure AD app ID and app secret for authentication or user-based auth.
 
.PARAMETER Tenant
Specifies the tenant (e.g. contoso.onmicrosoft.com) to which to authenticate.
 
.PARAMETER AppId
Specifies the Azure AD app ID (GUID) for the application that will be used to authenticate.
 
.PARAMETER AppSecret
Specifies the Azure AD app secret corresponding to the app ID that will be used to authenticate.

.PARAMETER Scopes
Specifies the user scopes for interactive authentication.
 
.EXAMPLE
Connect-ToGraph -TenantId $tenantID -AppId $app -AppSecret $secret
 
-#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (get-module microsoft.graph.authentication | Select-Object -expandproperty Version).major

        if ($AppId -ne "") {
            $body = @{
                grant_type    = "client_credentials";
                client_id     = $AppId;
                client_secret = $AppSecret;
                scope         = "https://graph.microsoft.com/.default";
            }
     
            $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token -Body $body
            $accessToken = $response.access_token
     
            $accessToken
            if ($version -eq 2) {
                write-host "Version 2 module detected"
                $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                write-host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
                $accesstokenfinal = $accessToken
            }
            $graph = Connect-MgGraph  -AccessToken $accesstokenfinal 
            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            if ($version -eq 2) {
                write-host "Version 2 module detected"
            }
            else {
                write-host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -scopes $scopes
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}    

##Connect to Graph
Connect-ToGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All, RoleAssignmentSchedule.ReadWrite.Directory, Domain.Read.All, Domain.ReadWrite.All, Directory.Read.All, Policy.ReadWrite.ConditionalAccess, DeviceManagementApps.ReadWrite.All, DeviceManagementConfiguration.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, openid, profile, email, offline_access"


###############################################################################################################
######                                          Add Functions                                            ######
###############################################################################################################

Function New-WordTable {
    [cmdletbinding(
        DefaultParameterSetName='Table'
    )]
    Param (
        [parameter()]
        [object]$WordObject,
        [parameter()]
        [object]$Object,
        [parameter()]
        [int]$Columns,
        [parameter()]
        [int]$Rows,
        [parameter(ParameterSetName='Table')]
        [switch]$AsTable,
        [parameter(ParameterSetName='List')]
        [switch]$AsList,
        [parameter()]
        [string]$TableStyle,
        [parameter()]
        [Microsoft.Office.Interop.Word.WdDefaultTableBehavior]$TableBehavior = 'wdWord9TableBehavior',
        [parameter()]
        [Microsoft.Office.Interop.Word.WdAutoFitBehavior]$AutoFitBehavior = 'wdAutoFitFixed'
    )
    #Specifying 0 index ensures we get accurate data from a single object
    $Properties = $Object[0].psobject.properties.name
    $Range = @($Word.Selection.Paragraphs)[-1].Range
    $Table = $WordObject.Selection.Tables.add($Range,$Rows,$Columns,$TableBehavior,$AutoFitBehavior)
 
    Switch ($PSCmdlet.ParameterSetName) {
        'Table' {
            If (-NOT $PSBoundParameters.ContainsKey('TableStyle')) {
                $Table.Style = "Medium Shading 1 - Accent 1"
            }
            $c = 1
            $r = 1
            #Build header
            $Properties | ForEach {
                Write-Verbose "Adding $($_)"
                $Table.cell($r,$c).range.Bold=1
                $Table.cell($r,$c).range.text = $_
                $c++
            }  
            $c = 1    
            #Add Data
            For ($i=0; $i -lt (($Object | Measure-Object).Count); $i++) {
                $Properties | ForEach {
                    $Table.cell(($i+2),$c).range.Bold=0
                    $Table.cell(($i+2),$c).range.text = $Object[$i].$_
                    $c++
                }
                $c = 1 
            }                 
        }
        'List' {
            If (-NOT $PSBoundParameters.ContainsKey('TableStyle')) {
                $Table.Style = "Light Shading - Accent 1"
            }
            $c = 1
            $r = 1
            $Properties | ForEach {
            $output = $Object.$_
            if ([string]::IsNullOrEmpty($output)) {
            $data = "null"
            }
            else {
            if ($output -is [string]) {
            $data = $output

            }
            else {
            $data = $output.ToString()

            }
            }

                $Table.cell($r,$c).range.Bold=1
                $Table.cell($r,$c).range.text = $_
                $c++
                $Table.cell($r,$c).range.Bold=0
                $Table.cell($r,$c).range.text = $data
                $c--
                $r++
            }
        }
    }

}

Function New-WordText {
    Param (
        [string]$Text,
        [int]$Size = 11,
        [string]$Style = 'Normal',
        [Microsoft.Office.Interop.Word.WdColor]$ForegroundColor = "wdColorAutomatic",
        [switch]$Bold,
        [switch]$Italic,
        [switch]$NoNewLine
    )  
    Try {
        $Selection.Style = $Style
    } Catch {
        Write-Warning "Style: `"$Style`" doesn't exist! Try another name."
        Break
    }
 
    If ($Style -notmatch 'Title|^Heading'){
        $Selection.Font.Size = $Size  
        If ($PSBoundParameters.ContainsKey('Bold')) {
            $Selection.Font.Bold = 1
        } Else {
            $Selection.Font.Bold = 0
        }
        If ($PSBoundParameters.ContainsKey('Italic')) {
            $Selection.Font.Italic = 1
        } Else {
            $Selection.Font.Italic = 0
        }          
        $Selection.Font.Color = $ForegroundColor
    }
 
    $Selection.TypeText($Text)
 
    If (-NOT $PSBoundParameters.ContainsKey('NoNewLine')) {
        $Selection.TypeParagraph()
    }
}

Function Get-IntuneApplication(){
    
    <#
    .SYNOPSIS
    This function is used to get applications from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any applications added
    .EXAMPLE
    Get-IntuneApplication
    Returns any applications configured in Intune
    .NOTES
    NAME: Get-IntuneApplication
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/mobileApps"
    
        try {
    
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value | Where-Object { ($_.'@odata.type').Contains("#microsoft.graph.winGetApp") }
    
            }
    
        }
    
        catch {
    
        }
    
    }

    Function Get-IntuneApplicationAssignments(){
    
        <#
        .SYNOPSIS
        This function is used to get application assignments from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets any application assignments
        .EXAMPLE
        Get-IntuneApplicationAssignments
        Returns any application assignments configured in Intune
        .NOTES
        NAME: Get-IntuneApplicationAssignments
        #>
        
        [cmdletbinding()]
        
        param
        (
            [Parameter(Position=0,mandatory=$true)]
            $id
        )
        
        $graphApiVersion = "Beta"
        $Resource = "deviceAppManagement/mobileApps"
        
            try {
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
                (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
            }
        
            catch {
        
            }
        
        }
    

Function Get-DeviceConfigurationPolicyGP(){
    
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface - Group Policies
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicyGP
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/groupPolicyConfigurations"
    
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
     
}


Function Get-DeviceConfigurationPolicyGPAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get Group Policy assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any group policy assignments
    .EXAMPLE
    Get-DeviceConfigurationPolicyGPAssignments
    Returns any group policy assignments configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicyGPAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/groupPolicyConfigurations"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }

#############################################################################################################    

Function Get-ConditionalAccessPolicy(){
    
    <#
    .SYNOPSIS
    This function is used to get conditional access policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any conditional access policies
    .EXAMPLE
    Get-ConditionalAccessPolicy
    Returns any conditional access policies in Azure
    .NOTES
    NAME: Get-ConditionalAccessPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    

    $graphApiVersion = "beta"
    $DCP_resource = "identity/conditionalAccess/policies"
    
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
        }
        catch {}
    
     
}


####################################################

Function Get-DeviceConfigurationPolicy(){
    
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
        
}

Function Get-DeviceConfigurationPolicyAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get configuration Policy assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any configuration policy assignments
    .EXAMPLE
    Get-DeviceConfigurationPolicyAssignments
    Returns any configuration policy assignments configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicyAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/deviceConfigurations"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }


    
##########################################################################################

Function Get-GroupPolicyConfigurationsDefinitionValues()
{
	
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
	
	[cmdletbinding()]
	Param (
		
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationID
		
	)
	
	$graphApiVersion = "Beta"
	#$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues?`$filter=enabled eq true"
	$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues"
	
	try {	
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
		(Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
		
    }
    catch{}
	

	
}

####################################################
Function Get-GroupPolicyConfigurationsDefinitionValuesPresentationValues()
{
	
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
	
	[cmdletbinding()]
	Param (
		
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationID,
		[string]$GroupPolicyConfigurationsDefinitionValueID
		
	)
	$graphApiVersion = "Beta"
	
	$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/presentationValues?`$expand=presentation"
	try {
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
		(Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    }
    catch {}
		
	
}

Function Get-GroupPolicyConfigurationsDefinitionValuesdefinition ()
{
   <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
	
	[cmdletbinding()]
	Param (
		
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationID,
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationsDefinitionValueID
		
	)
	$graphApiVersion = "Beta"
	$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/definition"
	try {
		
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
		
		$responseBody = Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
    }
    catch{}
		
		
	$responseBody
}


Function Get-GroupPolicyDefinitionsPresentations ()
{
   <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
	
	[cmdletbinding()]
	Param (
		
		
		[Parameter(Mandatory = $true)]
		[string]$groupPolicyDefinitionsID,
		[Parameter(Mandatory = $true)]
		[string]$GroupPolicyConfigurationsDefinitionValueID
		
	)
	$graphApiVersion = "Beta"
	$DCP_resource = "deviceManagement/groupPolicyConfigurations/$groupPolicyDefinitionsID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/presentationValues?`$expand=presentation"
		$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
		try {
		(Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value.presentation
        }
        catch {}
		
	
}


####################################################
    
Function Get-DeviceConfigurationPolicySC(){
    
            <#
            .SYNOPSIS
            This function is used to get device configuration policies from the Graph API REST interface - SETTINGS CATALOG
            .DESCRIPTION
            The function connects to the Graph API Interface and gets any device configuration policies
            .EXAMPLE
            Get-DeviceConfigurationPolicySC
            Returns any device configuration policies configured in Intune
            .NOTES
            NAME: Get-DeviceConfigurationPolicySC
            #>
            
            [cmdletbinding()]
            
            param
            (
                $id
            )
            
            $graphApiVersion = "beta"
            $DCP_resource = "deviceManagement/configurationPolicies"
            try {
                    if($id){
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
            
                    }
            
                    else {
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            
                    }
                }
                catch {}
            
            
}

Function Get-DeviceConfigurationPolicySCAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get settings catalog Policy assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any settings catalog policy assignments
    .EXAMPLE
    Get-DeviceConfigurationPolicySCAssignments
    Returns any settings catalog policy assignments configured in Intune
    .NOTES
    NAME: Get-DeviceConfigurationPolicySCAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/configurationPolicies"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }

            
################################################################################################


####################################################
    
Function Get-DeviceProactiveRemediations(){
    
    <#
    .SYNOPSIS
    This function is used to get device proactive remediations from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device proactive remediations
    .EXAMPLE
    Get-DeviceproactiveRemediations
    Returns any device proactive remediations configured in Intune
    .NOTES
    NAME: Get-Deviceproactiveremediations
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/devicehealthscripts"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-DeviceProactiveRemediationsAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get proactive remediation assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any proactive remediation assignments
    .EXAMPLE
    Get-DeviceProactiveRemediationsAssignments
    Returns any proactive remediation assignments configured in Intune
    .NOTES
    NAME: Get-DeviceProactiveRemediationsAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/devicehealthscripts"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }
    
################################################################################################
    
Function Get-DeviceCompliancePolicy(){
    
            <#
            .SYNOPSIS
            This function is used to get device compliance policies from the Graph API REST interface
            .DESCRIPTION
            The function connects to the Graph API Interface and gets any device compliance policies
            .EXAMPLE
            Get-DeviceCompliancepolicy
            Returns any device compliance policies configured in Intune
            .NOTES
            NAME: Get-devicecompliancepolicy
            #>
            
            [cmdletbinding()]
            
            param
            (
                $id
            )
            
            $graphApiVersion = "beta"
            $DCP_resource = "deviceManagement/deviceCompliancePolicies"
            try {
                    if($id){
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
            
                    }
            
                    else {
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            
                    }
                }
                catch {}
            
}

Function Get-DeviceCompliancePolicyAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get compliance policy assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any compliance policy assignments
    .EXAMPLE
    Get-DeviceCompliancePolicyAssignments
    Returns any compliance policy assignments configured in Intune
    .NOTES
    NAME: Get-DeviceCompliancePolicyAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/deviceCompliancePolicies"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }
            
#################################################################################################
Function Get-DeviceSecurityPolicy(){
    
    <#
    .SYNOPSIS
    This function is used to get device security policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device security policies
    .EXAMPLE
    Get-DeviceSecurityPolicy
    Returns any device compliance policies configured in Intune
    .NOTES
    NAME: Get-DeviceSecurityPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/intents"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
   
}

Function Get-DeviceSecurityPolicyAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get security policy assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any security policy assignments
    .EXAMPLE
    Get-DeviceSecurityPolicyAssignments
    Returns any security policy assignments configured in Intune
    .NOTES
    NAME: Get-DeviceSecurityPolicyAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/intents"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }

#################################################################################################  

Function Get-ManagedAppProtectionAndroid(){

    <#
    .SYNOPSIS
    This function is used to get managed app protection configuration from the Graph API REST interface Android
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any managed app protection policy Android
    .EXAMPLE
    Get-ManagedAppProtectionAndroid
    .NOTES
    NAME: Get-ManagedAppProtectionAndroid
    #>
    
    param
    (
        $id
    )
    $graphApiVersion = "Beta"
    
            $Resource = "deviceAppManagement/androidManagedAppProtections"
        try {
            if($id){
            
                $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource('$id')"
                (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        
                }
        
                else {
        
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
                    Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject  
        
                }
            }
            catch {}        
        
        
    
}

Function Get-ManagedAppProtectionAndroidAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get Android app protection policy assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Android app protection  policy assignments
    .EXAMPLE
    Get-ManagedAppProtectionAndroidAssignments
    Returns any Android app protection  policy assignments configured in Intune
    .NOTES
    NAME: Get-ManagedAppProtectionAndroidAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/androidManagedAppProtections"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }

#################################################################################################  

Function Get-ManagedAppProtectionIOS(){

    <#
    .SYNOPSIS
    This function is used to get managed app protection configuration from the Graph API REST interface IOS
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any managed app protection policy IOS
    .EXAMPLE
    Get-ManagedAppProtectionIOS
    .NOTES
    NAME: Get-ManagedAppProtectionIOS
    #>
    param
    (
        $id
    )

    $graphApiVersion = "Beta"
    
                $Resource = "deviceAppManagement/iOSManagedAppProtections"
        try {
                if($id){
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource('$id')"
                    (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
            
                    }
            
                    else {
            
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
                        Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
            
                    }
                }
                catch {}
        
}

Function Get-ManagedAppProtectionIOSAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get iOS app protection policy assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any iOS app protection  policy assignments
    .EXAMPLE
    Get-ManagedAppProtectionIOSAssignments
    Returns any iOS app protection  policy assignments configured in Intune
    .NOTES
    NAME: Get-ManagedAppProtectionIOSAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/iOSManagedAppProtections"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }
    
####################################################
Function Get-GraphAADGroups(){
    
    <#
    .SYNOPSIS
    This function is used to get AAD Groups from the Graph API REST interface 
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any AAD Groups
    .EXAMPLE
    Get-GraphAADGroups
    Returns any AAD Groups
    .NOTES
    NAME: Get-GraphAADGroups
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "Groups"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$Filter=onPremisesSyncEnabled ne true&`$count=true"
            #(Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
            Get-MgGroup | Where-Object OnPremisesSyncEnabled -NE true
    
            }
        }
        catch {}
    
}

#################################################################################################  

Function Get-AutoPilotProfile(){
    
                <#
                .SYNOPSIS
                This function is used to get autopilot profiles from the Graph API REST interface 
                .DESCRIPTION
                The function connects to the Graph API Interface and gets any autopilot profiles
                .EXAMPLE
                Get-AutoPilotProfile
                Returns any autopilot profiles configured in Intune
                .NOTES
                NAME: Get-AutoPilotProfile
                #>
                
                [cmdletbinding()]
                
                param
                (
                    $id
                )
                
                $graphApiVersion = "beta"
                $DCP_resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
                try {
                        if($id){
                
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                        (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
                
                        }
                
                        else {
                
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                        (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
                
                        }
                    }
                    catch {}
                
}

Function Get-AutoPilotProfileAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get autopilot profile assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any autopilot profile assignments
    .EXAMPLE
    Get-AutoPilotProfileAssignments
    Returns any autopilot profile assignments configured in Intune
    .NOTES
    NAME: Get-AutoPilotProfileAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }

#################################################################################################

Function Get-AutoPilotESP(){
    
                    <#
                    .SYNOPSIS
                    This function is used to get autopilot ESP from the Graph API REST interface 
                    .DESCRIPTION
                    The function connects to the Graph API Interface and gets any autopilot ESP
                    .EXAMPLE
                    Get-AutoPilotESP
                    Returns any autopilot ESPs configured in Intune
                    .NOTES
                    NAME: Get-AutoPilotESP
                    #>
                    
                    [cmdletbinding()]
                    
                    param
                    (
                        $id
                    )
                    
                    $graphApiVersion = "beta"
                    $DCP_resource = "deviceManagement/deviceEnrollmentConfigurations"
                    try {
                            if($id){
                    
                            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)?`$filter=id eq '$id'"
                            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).value
                    
                            }
                    
                            else {
                    
                            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
                            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
                    
                            }
                        }
                        catch{}
}

Function Get-AutoPilotESPAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get autopilot ESP assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any autopilot ESP assignments
    .EXAMPLE
    Get-AutoPilotESPAssignments
    Returns any autopilot ESP assignments configured in Intune
    .NOTES
    NAME: Get-AutoPilotESPAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/deviceEnrollmentConfigurations"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }
                
#################################################################################################    

Function Get-DecryptedDeviceConfigurationPolicy(){

    <#
    .SYNOPSIS
    This function is used to decrypt device configuration policies from an json array with the use of the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and decrypt Windows custom device configuration policies that is encrypted
    .EXAMPLE
    Decrypt-DeviceConfigurationPolicy -dcps $DCPs
    Returns any device configuration policies configured in Intune in clear text without encryption
    .NOTES
    NAME: Decrypt-DeviceConfigurationPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $dcpid
    )
    
    $graphApiVersion = "Beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    $dcp = Get-DeviceConfigurationPolicy -id $dcpid
        if ($dcp.'@odata.type' -eq "#microsoft.graph.windows10CustomConfiguration") {
            # Convert policy of type windows10CustomConfiguration
            foreach ($omaSetting in $dcp.omaSettings) {
                    if ($omaSetting.isEncrypted -eq $true) {
                        $DCP_resource_function = "$($DCP_resource)/$($dcp.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$($omaSetting.secretReferenceValueId)')"
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource_function)"
                        $value = ((Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value)

                        #Remove any unnecessary properties
                        $omaSetting.PsObject.Properties.Remove("isEncrypted")
                        $omaSetting.PsObject.Properties.Remove("secretReferenceValueId")
                        $omaSetting.value = $value
                    }

            }
        }
    
    $dcp

}


Function Get-DeviceManagementScripts(){
    
    <#
    .SYNOPSIS
    This function is used to get device PowerShell scripts from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device scripts
    .EXAMPLE
    Get-DeviceManagementScripts
    Returns any device management scripts configured in Intune
    .NOTES
    NAME: Get-DeviceManagementScripts
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/devicemanagementscripts"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-DeviceManagementScriptsAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get PowerShell script assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any PowerShell script assignments
    .EXAMPLE
    Get-DeviceManagementScriptsAssignments
    Returns any PowerShell script assignments configured in Intune
    .NOTES
    NAME: Get-DeviceManagementScriptsAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/devicemanagementscripts"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }
    
################################################################################################
Function Get-Win365UserSettings(){
    
    <#
    .SYNOPSIS
    This function is used to get Windows 365 User Settings Policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device scriptsWindows 365 User Settings Policies
    .EXAMPLE
    Get-Win365UserSettings
    Returns any Windows 365 User Settings Policies configured in Intune
    .NOTES
    NAME: Get-Win365UserSettings
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/virtualEndpoint/userSettings"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-Win365UserSettingsAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get Windows 365 User Settings Policies assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Windows 365 User Settings Policies assignments
    .EXAMPLE
    Get-Win365UserSettingsAssignments
    Returns any Windows 365 User Settings Policies assignments configured in Intune
    .NOTES
    NAME: Get-Win365UserSettingsAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/virtualEndpoint/userSettings"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }

Function Get-Win365ProvisioningPolicies(){
    
    <#
    .SYNOPSIS
    This function is used to get Windows 365 Provisioning Policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device scriptsWindows 365 Provisioning Policies
    .EXAMPLE
    Get-Win365ProvisioningPolicies
    Returns any Windows 365 Provisioning Policies configured in Intune
    .NOTES
    NAME: Get-Win365ProvisioningPolicies
    #>
    
    [cmdletbinding()]
    
    param
    (
        $id
    )
    
    $graphApiVersion = "beta"
    $DCP_resource = "deviceManagement/virtualEndpoint/provisioningPolicies"
    try {
            if($id){
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
    
            }
    
            else {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject).Value
    
            }
        }
        catch {}
    
   
}

Function Get-Win365ProvisioningPoliciesAssignments(){
    
    <#
    .SYNOPSIS
    This function is used to get Windows 365 Provisioning Policies assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Windows 365 Provisioning Policies assignments
    .EXAMPLE
    Get-Win365ProvisioningPoliciesAssignments
    Returns any Windows 365 Provisioning Policies assignments configured in Intune
    .NOTES
    NAME: Get-Win365ProvisioningPoliciesAssignments
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Position=0,mandatory=$true)]
        $id
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/virtualEndpoint/provisioningPolicies"
    
        try {
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id/assignments"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)
        }
    
        catch {
    
        }
    
    }

Function Get-SettingsCatalogPolicySettings(){

<#
.SYNOPSIS
This function is used to get Settings Catalog policy Settings from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Settings Catalog policy Settings
.EXAMPLE
Get-SettingsCatalogPolicySettings -policyid policyid
Returns any Settings Catalog policy Settings configured in Intune
.NOTES
NAME: Get-SettingsCatalogPolicySettings
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $policyid
)

$graphApiVersion = "beta"
$Resource = "deviceManagement/configurationPolicies('$policyid')/settings?`$expand=settingDefinitions"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

        $Response = (Invoke-MgGraphRequest -Uri $uri -Method Get -OutputType PSObject)

        $AllResponses = $Response.value
     
        $ResponseNextLink = $Response."@odata.nextLink"

        while ($ResponseNextLink -ne $null){

            $Response = (Invoke-MgGraphRequest -Uri $ResponseNextLink -Method Get -OutputType PSObject)
            $ResponseNextLink = $Response."@odata.nextLink"
            $AllResponses += $Response.value

        }

        return $AllResponses

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

####################################################


#################################################################################################
function getpolicyjson() {
        <#
    .SYNOPSIS
    This function is used to add a new device policy by copying an existing policy, manipulating the JSON and then adding via Graph
    .DESCRIPTION
    The function grabs an existing policy, decrypts if requires, renames, removes any GUIDs and then returns the JSON
    .EXAMPLE
    getpolicyjson -policy $policy -name $name
    .NOTES
    NAME: getpolicyjson
    #>

    param
    (
        $resource,
        $policyid
    )
    $id = $policyid
    write-host $resource
    $graphApiVersion = "beta"
    switch ($resource) {
    "deviceManagement/deviceConfigurations" {
     $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
     $policy = Get-DecryptedDeviceConfigurationPolicy -dcpid $id
     $assignment = Get-DeviceConfigurationPolicyAssignments -id $id
     $type = "Configuration Policy"

    }

    "deviceManagement/groupPolicyConfigurations" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceConfigurationPolicyGP -id $id
        $assignment = Get-DeviceConfigurationPolicyGPAssignments -id $id
        $type = "Admin Template"
       }

    "deviceManagement/devicehealthscripts" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceProactiveRemediations -id $id
        $assignment = Get-DeviceProactiveRemediationsAssignments -id $id
        $type = "Proactive Remedation"
       }

       "deviceManagement/devicemanagementscripts" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceManagementScripts -id $id
        $assignment = Get-DeviceManagementScriptsAssignments -id $id
        $type = "PowerShell Script"
       }
    

       "deviceManagement/configurationPolicies" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceConfigurationPolicysc -id $id
        $policy | Add-Member -MemberType NoteProperty -Name 'settings' -Value @() -Force
        #$settings = Invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$id/settings" | Get-MSGraphAllPages
        $settings = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$id/settings?`$expand=settingDefinitions&top=1000" -OutputType PSObject
        $settings = $settings.value
        $settings =  $settings | select-object * -ExcludeProperty '@odata.count'
        if ($settings -isnot [System.Array]) {
            $policy.Settings = @($settings)
        } else {
            $policy.Settings = $settings
        }
        

        $assignment = get-deviceconfigurationpolicyscassignments -id $id
        $type = "Settings Catalog"

    }
    
    "deviceManagement/deviceCompliancePolicies" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-DeviceCompliancePolicy -id $id
            $scheduledActionsForRule = @(
                @{
                    ruleName = "PasswordRequired"
                    scheduledActionConfigurations = @(
                        @{
                            actionType = "block"
                            gracePeriodHours = 0
                            notificationTemplateId = ""
                        }
                    )
                }
            )
            $policy | Add-Member -NotePropertyName scheduledActionsForRule -NotePropertyValue $scheduledActionsForRule
            $assignment = Get-DeviceCompliancePolicyAssignments -id $id
            $type = "Compliance Policy"
            
            
    }
    "deviceManagement/intents" {
        $policy = Get-DeviceSecurityPolicy -id $id
        $templateid = $policy.templateID
        $uri = "https://graph.microsoft.com/beta/deviceManagement/templates/$templateId/createInstance"
        #$template = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$templateid" -Headers $authToken -Method Get
        $template = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$templateid" -OutputType PSObject
        $template = $template
        #$templateCategory = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$templateid/categories" -Headers $authToken -Method Get
        $templateCategories = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/templates/$templateid/categories" -OutputType PSObject).Value
        #$intentSettingsDelta = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$id/categories/$($templateCategory.id)/settings" -Headers $authToken -Method Get).value
        $intentSettingsDelta = @()
        foreach ($templateCategory in $templateCategories) {
            # Get all configured values for the template categories
            Write-Verbose "Requesting Intent Setting Values"
            $intentSettingsDelta += (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($policy.id)/categories/$($templateCategory.id)/settings").value
        }
           $policy = @{
            "displayName" = $policy.DisplayName
            "description" = $policy.description
            "settingsDelta" = $intentSettingsDelta
            "roleScopeTagIds" = $policy.roleScopeTagIds
        }
        $policy | Add-Member -NotePropertyName displayName -NotePropertyValue $newname
        $assignment = Get-DeviceSecurityPolicyAssignments -id $id
        $type = "Security Policy"



    }
    "deviceManagement/windowsAutopilotDeploymentProfiles" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-AutoPilotProfile -id $id
        $assignment = Get-AutoPilotProfileAssignments -id $id
        $type = "AutoPilot Profile"
    }
    "deviceManagement/deviceEnrollmentConfigurations" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-AutoPilotESP -id $id
        $assignment = Get-AutoPilotESPAssignments -id $id
        $type = "AutoPilot ESP"
    }
    "deviceManagement/virtualEndpoint/userSettings" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-Win365UserSettings -id $id
        $assignment = Get-Win365UserSettingsAssignments -id $id
        $type = "Windows 365 User Settings"
    }
    "deviceManagement/virtualEndpoint/provisioningPolicies" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $policy = Get-Win365ProvisioningPolicies -id $id
        $assignment = Get-Win365ProvisioningPoliciesAssignments -id $id
        $type = "Windows 365 Provisioning Policy"
    }
    "deviceAppManagement/managedAppPoliciesandroid" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies"
        $policy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies('$id')" -OutputType PSObject
        $assignment = Get-ManagedAppProtectionAndroidAssignments -id $id
        $type = "Android App Protection Policy"

    }
    "deviceAppManagement/managedAppPoliciesios" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies"
        #$policy = Invoke-RestMethod -Uri "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies('$id')" -Headers $authToken -Method Get
        $policy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/managedAppPolicies('$id')" -OutputType PSObject
        $assignment = Get-ManagedAppProtectioniOSAssignments -id $id
        $type = "iOS App Protection Policy"
    }

    "conditionalaccess" {
        $uri = "conditionalaccess"
        $policy = Get-ConditionalAccessPolicy -id $id
        $assignment = "Not Available for Conditional Access"
        $type = "Conditional Access Policy"
    }
    "deviceAppManagement/mobileApps" {
        $uri = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/mobileApps"
        $policy = Get-IntuneApplication -id $id
        $assignment = Get-IntuneApplicationAssignments -id $id
        $type = "Intune Application"
        }
    }

    $policy = $policy | Select-Object * -ExcludeProperty roleScopeTagIds
    return $policy, $type, $assignment

}



###############################################################################################################
######                                          Grab the Profiles                                        ######
###############################################################################################################
$configuration = @()
##Get Config Policies
$configuration += Get-DeviceConfigurationPolicy | Select-Object ID, DisplayName, Description, @{N='Type';E={"Config Policy"}}

##Get Admin Template Policies
$configuration += Get-DeviceConfigurationPolicyGP | Select-Object ID, DisplayName, Description, @{N='Type';E={"Admin Template"}}


##Get Settings Catalog Policies
$configuration += Get-DeviceConfigurationPolicySC | Select-Object ID, @{N='DisplayName';E={$_.Name}}, Description , @{N='Type';E={"Settings Catalog"}}

##Get Compliance Policies
$configuration += Get-DeviceCompliancePolicy | Select-Object ID, DisplayName, Description, @{N='Type';E={"Compliance Policy"}}

##Get Proactive Remediations
$configuration += Get-DeviceProactiveRemediations | Select-Object ID, DisplayName, Description, @{N='Type';E={"Proactive Remediation"}}

##Get Device Scripts
$configuration += Get-DeviceManagementScripts | Select-Object ID, DisplayName, Description, @{N='Type';E={"PowerShell Script"}}

##Get Security Policies
$configuration += Get-DeviceSecurityPolicy | Select-Object ID, DisplayName, Description, @{N='Type';E={"Security Policy"}}

##Get Autopilot Profiles
$configuration += Get-AutoPilotProfile | Select-Object ID, DisplayName, Description, @{N='Type';E={"Autopilot Profile"}}

##Get AAD Groups
$configuration += Get-GraphAADGroups | Select-Object ID, DisplayName, Description, @{N='Type';E={"AAD Group"}}

##Get Autopilot ESP
$configuration += Get-AutoPilotESP | Select-Object ID, DisplayName, Description, @{N='Type';E={"Autopilot ESP"}}

##Get App Protection Policies
#Android
$androidapp = Get-ManagedAppProtectionAndroid | Select-Object -expandproperty Value
$configuration += $androidapp | Select-Object ID, DisplayName, Description, @{N='Type';E={"Android App Protection"}}
#IOS
$iosapp = Get-ManagedAppProtectionios | Select-Object -expandproperty Value
$configuration += $iosapp | Select-Object ID, DisplayName, Description, @{N='Type';E={"iOS App Protection"}}

##Get Conditional Access Policies
$configuration += Get-ConditionalAccessPolicy | Select-Object ID, DisplayName, @{N='Type';E={"Conditional Access Policy"}}

##Get Winget Apps
$configuration += Get-IntuneApplication | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Winget Application"}}

##Get Win365 User Settings
$configuration += Get-Win365UserSettings | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Win365 User Settings"}}

##Get Win365 Provisioning Policies
$configuration += Get-Win365ProvisioningPolicies | Select-Object ID, DisplayName, Description,  @{N='Type';E={"Win365 Provisioning Policy"}}


$configuration | foreach-object {

##Find out what it is
$id = $_.ID
write-host $id
$policy = Get-DeviceConfigurationPolicy -id $id
$catalog = Get-DeviceConfigurationPolicysc -id $id
$compliance = Get-DeviceCompliancePolicy -id $id
$security = Get-DeviceSecurityPolicy -id $id
$autopilot = Get-AutoPilotProfile -id $id
$esp = Get-AutoPilotESP -id $id
$android = Get-ManagedAppProtectionAndroid -id $id
$ios = Get-ManagedAppProtectionios -id $id
$gp = Get-DeviceConfigurationPolicyGP -id $id
$ca = Get-ConditionalAccessPolicy -id $id
$proac = Get-DeviceProactiveRemediations -id $id
$aad = Get-GraphAADGroups -id $id
$wingetapp = Get-IntuneApplication -id $id
$scripts = Get-DeviceManagementScripts -id $id
$win365usersettings = Get-Win365UserSettings -id $id
$win365provisioning = Get-Win365ProvisioningPolicies -id $id




$Word = New-Object -ComObject Word.Application
$Word.Visible = $True
$Document = $Word.Documents.Add()
$Selection = $Word.Selection


$domain = get-mgdomain | where-object IsDefault -eq $true
$domainname = $domain.id

#### ADD TITLE PAGE
New-WordText -Text ("Intune Documentation for " + $domainname) -Style 'Title'
New-WordText -Text "Documentation compiled at $(Get-Date)."
$Selection.InsertBreak()
#### ADD TABLE OF CONTENTS
$range = $Selection.Range
$toc = $Document.TablesOfContents.Add($range)
$Selection.TypeParagraph()
$Selection.InsertBreak()

# Copy it
if ($null -ne $policy) {
    # Standard Device Configuration Policy
write-host "It's a policy"
$id = $policy.id
$Resource = "deviceManagement/deviceConfigurations"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = ($copypolicy[2]).value
$policyname = $policycode.displayName

######################################################################################
#####                              CREATE CONTENT                               ######
######################################################################################

##Table Heading
New-WordText -Text ($policytype + " --> " + $policyname) -Style 'Heading 1'
##Table One - Policy Code
New-WordTable -WordObject $word -Object $policycode -Columns 2 -Rows ($policycode.PSObject.Properties | Measure-Object).Count -AsList
##Assignments
$allassignments = $policyassignments.target
##Move to the bottom of the table
$selection.EndKey(6,0)
##Add a gap
$Selection.TypeParagraph()
$Selection.TypeParagraph()

##Assignments Heading
New-WordText -Text ("Assignments") -Style 'Heading 2'
##Create arrays for the groups to loop through later
$includedgroups = @()
$excludedgroups = @()
## Add to new array depending if included or excluded
foreach ($assignment in $allassignments) {
$assignmenttype = $assignment.'@odata.type'
$assignmentgroupid = $assignment.groupId
$groupname = (Get-GraphAADGroups -id $assignmentgroupid).displayName
if ($assignmenttype -eq "#microsoft.graph.groupAssignmentTarget") {

##Included
$includedgroups += $groupname + " - " + $assignmentgroupid
}

if ($assignmenttype -eq "#microsoft.graph.exclusionGroupAssignmentTarget") {
##Excluded
$excludedgroups += $groupname + " - " + $assignmentgroupid
}

}
##Count the groups so we don't add headers with no content
$includedcount = $includedgroups.Count
$excludedcount = $excludedgroups.Count

##Add included groups
if ($includedcount -ge 1) {
New-WordText -Text ("Included") -Style 'Heading 3'
foreach ($group in $includedgroups) {
New-WordText -Text $group
}

}

##Add excluded groups
if ($excludedcount -ge 1) {
New-WordText -Text ("Excluded") -Style 'Heading 3'
foreach ($group in $excludedgroups) {
New-WordText -Text $group
}

}
##Throw a page
$Selection.InsertBreak()
######################################################################################
#####                          END CREATE CONTENT                               ######
######################################################################################


}

if ($null -ne $gp) {
    # Standard Device Configuration Policy
write-host "It's an Admin Template"
$id = $gp.id
$Resource = "deviceManagement/groupPolicyConfigurations"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]

##Admin Templates are tricky so we need to grab the actual values
                $GroupPolicyConfigurationsDefinitionValues = Get-GroupPolicyConfigurationsDefinitionValues -GroupPolicyConfigurationID $id
                $OutDefjson = @()
	                foreach ($GroupPolicyConfigurationsDefinitionValue in $GroupPolicyConfigurationsDefinitionValues)
	                    {
		                    $DefinitionValuedefinition = Get-GroupPolicyConfigurationsDefinitionValuesdefinition -GroupPolicyConfigurationID $id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		                    $DefinitionValuedefinitionID = $DefinitionValuedefinition.id
		                    $DefinitionValuedefinitionDisplayName = $DefinitionValuedefinition.displayName
		                    $GroupPolicyDefinitionsPresentations = Get-GroupPolicyDefinitionsPresentations -groupPolicyDefinitionsID $id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		                    $DefinitionValuePresentationValues = Get-GroupPolicyConfigurationsDefinitionValuesPresentationValues -GroupPolicyConfigurationID $id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		                    $OutDef = New-Object -TypeName PSCustomObject
                            $OutDef | Add-Member -MemberType NoteProperty -Name "Setting Name" -Value $DefinitionValuedefinitionDisplayName
                            $OutDef | Add-Member -MemberType NoteProperty -Name "enabled" -value $($GroupPolicyConfigurationsDefinitionValue.enabled.tostring().tolower())
                                if ($DefinitionValuePresentationValues) {
                                    $i = 0
                                    $PresValues = @()
                                    foreach ($Pres in $DefinitionValuePresentationValues) {
                                        $P2 = ($pres | Select-Object -Property *).presentation
                                        $P3 = ($pres | Select-Object -Property *).values
                                        $P = $p2 | Select-Object label
                                        $Pa = $p3 | Select-Object name
                                        $Pb = ($pres | Select-Object value)
                                        $PresValues += $P
                                        $PresValues += $Pa
                                        $PresValues += $Pb
                                        $i++
                                    }
                                $OutDef | Add-Member -MemberType NoteProperty -Name "presentationValues" -Value $PresValues
                                }
		                    $OutDefjson += ($OutDef | ConvertTo-Json -Depth 10).replace("\u0027","'")
                        }

##It's a nested array so now grab the settings into a new array to inject into our main policycode
$extratablecontent = $OutDefjson | convertfrom-json
$adminarraycontent = @()
foreach ($content in $extratablecontent) {
$adminarraycontent += $content.'Setting Name'
$adminarraycontent +=  $content.enabled
$adminarraycontent +=  ($content.presentationValues).label
$adminarraycontent +=  ($content.presentationValues).value
$adminarraycontent +=  ($content.presentationValues).name

}

##Convert to a string
$contenttoadd = $adminarraycontent | out-string

##Add to the array
$policycode | Add-Member -Name "SettingsExpanded" -Type NoteProperty -Value $contenttoadd -Force

######################################################################################
#####                              CREATE CONTENT                               ######
######################################################################################
$policyname = $policycode.displayName

##Table Heading
New-WordText -Text ($policytype + " --> " + $policyname) -Style 'Heading 1'
##Table One - Policy Code
New-WordTable -WordObject $word -Object $policycode -Columns 2 -Rows ($policycode.PSObject.Properties | Measure-Object).Count -AsList
##Assignments
$allassignments = ($policyassignments.value).target
##Move to the bottom of the table
$selection.EndKey(6,0)
##Add a gap
$Selection.TypeParagraph()
$Selection.TypeParagraph()

##Assignments Heading
New-WordText -Text ("Assignments") -Style 'Heading 2'
##Create arrays for the groups to loop through later
$includedgroups = @()
$excludedgroups = @()
## Add to new array depending if included or excluded
foreach ($assignment in $allassignments) {
$assignmenttype = $assignment.'@odata.type'
$assignmentgroupid = $assignment.groupId
$groupname = (Get-GraphAADGroups -id $assignmentgroupid).displayName
if ($assignmenttype -eq "#microsoft.graph.groupAssignmentTarget") {

##Included
$includedgroups += $groupname + " - " + $assignmentgroupid
}

if ($assignmenttype -eq "#microsoft.graph.exclusionGroupAssignmentTarget") {
##Excluded
$excludedgroups += $groupname + " - " + $assignmentgroupid
}

}
##Count the groups so we don't add headers with no content
$includedcount = $includedgroups.Count
$excludedcount = $excludedgroups.Count

##Add included groups
if ($includedcount -ge 1) {
New-WordText -Text ("Included") -Style 'Heading 3'
foreach ($group in $includedgroups) {
New-WordText -Text $group
}

}

##Add excluded groups
if ($excludedcount -ge 1) {
New-WordText -Text ("Excluded") -Style 'Heading 3'
foreach ($group in $excludedgroups) {
New-WordText -Text $group
}

}
##Throw a page
$Selection.InsertBreak()
######################################################################################
#####                          END CREATE CONTENT                               ######
######################################################################################


}
if ($null -ne $catalog) {
    # Settings Catalog Policy
write-host "It's a Settings Catalog"
$id = $catalog.id
$Resource = "deviceManagement/configurationPolicies"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
$displayname = @()
$outvalue = @()
$settings = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$id/settings?`$expand=settingDefinitions&top=1000" -OutputType PSObject
foreach ($setting in $settings) {
$settingsvalues = $setting.value
$Settingname = $setting.settingDefinitions.description
foreach ($settingvalue in $settingsvalues) {
$settingInstance = $settingvalue.settingInstance
$settingdefinition = $settingvalue.settingDefinitions
foreach ($definition in $settingdefinition) {
$displayname += ($definition.displayName).ToString()


$datatype = $settingInstance.'@odata.type'
write-host $datatype
if ($datatype -eq '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'){
# Drop down and select one value
    $value = $settingInstance.choiceSettingValue.value
    $enabledcheck = $value.endswith('_1')
    if ($enabledcheck -eq $True) {
    $outvalue += "Enabled"
    }
    else {
    $outvalue += "Disabled"
    }
        if ($null -ne ($settingInstance.choiceSettingValue.children.simpleSettingValue.value)) {
    $outvalue += ($settingInstance.choiceSettingValue.children.simpleSettingValue.value).ToString()
    }
}
if ($datatype -eq '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'){
write-host "ME"
# String
    if ($null -ne ($settingInstance.simpleSettingValue.value)) {
    $outvalue += ($settingInstance.simpleSettingValue.value).ToString()    
    }
    
    if ($null -ne ($settingInstance.choiceSettingValue.children.simpleSettingValue.value)) {
    $outvalue += ($settingInstance.choiceSettingValue.children.simpleSettingValue.value).ToString()
    }
    if ($null -ne ($settingInstance.choiceSettingValue.children.simplesettingcollectionvalue)) {
    foreach ($childvalue in ($settingInstance.choiceSettingValue.children.simplesettingcollectionvalue)) {
    write-host "HERE"
    $outvalue += $childvalue.value.ToString()
    }
    }

}
if ($datatype -eq '#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance'){
# Multiple Choice Drop-Down
    write-host "Multi Drop-down"
}
if ($datatype -eq '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'){
# Multi Settings
    write-host "Multiple Settings"
}
if ($datatype -eq '#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance'){
# Group of Values
    write-host "Group of Values"
}
if ($datatype -eq '#microsoft.graph.deviceManagementConfigurationGroupSettingInstance') {
# Group Instance
    write-host "Group Instance"
}
}
}
}

$settingtable = 0..($displayname.Length-1) | Select-Object @{n="Setting Name";e={$displayname[$_]}}, @{n="Value";e={$outvalue[$_]}}

$settingoutputtext = $settingtable | fl | Out-String

##Add to the array
$policycode | Add-Member -Name "SettingsExpanded" -Type NoteProperty -Value $settingoutputtext -Force


######################################################################################
#####                              CREATE CONTENT                               ######
######################################################################################
$policyname = $policycode.name

##Table Heading
New-WordText -Text ($policytype + " --> " + $policyname) -Style 'Heading 1'
##Table One - Policy Code
New-WordTable -WordObject $word -Object $policycode -Columns 2 -Rows ($policycode.PSObject.Properties | Measure-Object).Count -AsList

##Assignments
$allassignments = ($policyassignments.value).target
##Move to the bottom of the table
$selection.EndKey(6,0)
##Add a gap
$Selection.TypeParagraph()
$Selection.TypeParagraph()

##Assignments Heading
New-WordText -Text ("Assignments") -Style 'Heading 2'
##Create arrays for the groups to loop through later
$includedgroups = @()
$excludedgroups = @()
## Add to new array depending if included or excluded
foreach ($assignment in $allassignments) {
$assignmenttype = $assignment.'@odata.type'
$assignmentgroupid = $assignment.groupId
$groupname = (Get-GraphAADGroups -id $assignmentgroupid).displayName
if ($assignmenttype -eq "#microsoft.graph.groupAssignmentTarget") {

##Included
$includedgroups += $groupname + " - " + $assignmentgroupid
}

if ($assignmenttype -eq "#microsoft.graph.exclusionGroupAssignmentTarget") {
##Excluded
$excludedgroups += $groupname + " - " + $assignmentgroupid
}

}
##Count the groups so we don't add headers with no content
$includedcount = $includedgroups.Count
$excludedcount = $excludedgroups.Count

##Add included groups
if ($includedcount -ge 1) {
New-WordText -Text ("Included") -Style 'Heading 3'
foreach ($group in $includedgroups) {
New-WordText -Text $group
}

}

##Add excluded groups
if ($excludedcount -ge 1) {
New-WordText -Text ("Excluded") -Style 'Heading 3'
foreach ($group in $excludedgroups) {
New-WordText -Text $group
}

}
##Throw a page
$Selection.InsertBreak()
######################################################################################
#####                          END CREATE CONTENT                               ######
######################################################################################

}
if ($null -ne $compliance) {
    # Compliance Policy
write-host "It's a Compliance Policy"
$id = $compliance.id
$Resource = "deviceManagement/deviceCompliancePolicies"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $proac) {
    # Proactive Remediations
write-host "It's a Proactive Remediation"
$id = $proac.id
$Resource = "deviceManagement/devicehealthscripts"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $scripts) {
    # Device Scripts
    write-host "It's a PowerShell Script"
$id = $scripts.id
$Resource = "deviceManagement/devicemanagementscripts"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}

if ($null -ne $security) {
    # Security Policy
write-host "It's a Security Policy"
$id = $security.id
$Resource = "deviceManagement/intents"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $autopilot) {
    # Autopilot Profile
write-host "It's an Autopilot Profile"
$id = $autopilot.id
$Resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $esp) {
    # Autopilot ESP
write-host "It's an AutoPilot ESP"
$id = $esp.id
$Resource = "deviceManagement/deviceEnrollmentConfigurations"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $android) {
    # Android App Protection
write-host "It's an Android App Protection Policy"
$id = $android.id
$Resource = "deviceAppManagement/managedAppPoliciesandroid"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $ios) {
    # iOS App Protection
write-host "It's an iOS App Protection Policy"
$id = $ios.id
$Resource = "deviceAppManagement/managedAppPoliciesios"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $aad) {
    # AAD Groups
write-host "It's an AAD Group"
$id = $aad.id
$Resource = "groups"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $ca) {
    # Conditional Access
write-host "It's a Conditional Access Policy"
$id = $ca.id
$Resource = "ConditionalAccess"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $wingetapp) {
    # Winget App
write-host "It's a Windows Application"
$id = $wingetapp.id
$Resource = "deviceAppManagement/mobileApps"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $win365usersettings) {
    # W365 User Settings
write-host "It's a W365 User Setting"
$id = $win365usersettings.id
$Resource = "deviceManagement/virtualEndpoint/userSettings"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
if ($null -ne $win365provisioning) {
    # W365 Provisioning Policy
write-host "It's a W365 Provisioning Policy"
$id = $win365provisioning.id
$Resource = "deviceManagement/virtualEndpoint/provisioningPolicies"
$copypolicy = getpolicyjson -resource $Resource -policyid $id
$policycode = $copypolicy[0]
$policytype = $copypolicy[1]
$policyassignments = $copypolicy[2]
}
}

$toc.Update()

##Save Word Document

##Output to PDF

##Upload to GitHub (if selected)

##Open folder

Stop-Transcript
# SIG # Begin signature block
# MIIoGQYJKoZIhvcNAQcCoIIoCjCCKAYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBtmMpT7Vog/KNx
# zlqhm9PXNzklfYQlIOQTRGYWvgU64KCCIRwwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqG
# SIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXH
# JQPE8pE3qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMf
# UBMLJnOWbfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w
# 1lbU5ygt69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRk
# tFLydkf3YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYb
# qMFkdECnwHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUm
# cJgmf6AaRyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP6
# 5x9abJTyUpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzK
# QtwYSH8UNM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo
# 80VgvCONWPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjB
# Jgj5FBASA31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXche
# MBK9Rp6103a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB
# /wIBADAdBgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDig
# NqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZI
# hvcNAQELBQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd
# 4ksp+3CKDaopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiC
# qBa9qVbPFXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl
# /Yy8ZCaHbJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeC
# RK6ZJxurJB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYT
# gAnEtp/Nh4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/
# a6fxZsNBzU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37
# xJV77QpfMzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmL
# NriT1ObyF5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0
# YgkPCr2B2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJ
# RyvmfxqkhQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIG
# sDCCBJigAwIBAgIQCK1AsmDSnEyfXs2pvZOu2TANBgkqhkiG9w0BAQwFADBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# HhcNMjEwNDI5MDAwMDAwWhcNMzYwNDI4MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA1bQvQtAorXi3XdU5WRuxiEL1M4zr
# PYGXcMW7xIUmMJ+kjmjYXPXrNCQH4UtP03hD9BfXHtr50tVnGlJPDqFX/IiZwZHM
# gQM+TXAkZLON4gh9NH1MgFcSa0OamfLFOx/y78tHWhOmTLMBICXzENOLsvsI8Irg
# nQnAZaf6mIBJNYc9URnokCF4RS6hnyzhGMIazMXuk0lwQjKP+8bqHPNlaJGiTUyC
# EUhSaN4QvRRXXegYE2XFf7JPhSxIpFaENdb5LpyqABXRN/4aBpTCfMjqGzLmysL0
# p6MDDnSlrzm2q2AS4+jWufcx4dyt5Big2MEjR0ezoQ9uo6ttmAaDG7dqZy3SvUQa
# khCBj7A7CdfHmzJawv9qYFSLScGT7eG0XOBv6yb5jNWy+TgQ5urOkfW+0/tvk2E0
# XLyTRSiDNipmKF+wc86LJiUGsoPUXPYVGUztYuBeM/Lo6OwKp7ADK5GyNnm+960I
# HnWmZcy740hQ83eRGv7bUKJGyGFYmPV8AhY8gyitOYbs1LcNU9D4R+Z1MI3sMJN2
# FKZbS110YU0/EpF23r9Yy3IQKUHw1cVtJnZoEUETWJrcJisB9IlNWdt4z4FKPkBH
# X8mBUHOFECMhWWCKZFTBzCEa6DgZfGYczXg4RTCZT/9jT0y7qg0IU0F8WD1Hs/q2
# 7IwyCQLMbDwMVhECAwEAAaOCAVkwggFVMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYD
# VR0OBBYEFGg34Ou2O/hfEYb7/mF7CIhl9E5CMB8GA1UdIwQYMBaAFOzX44LScV1k
# TN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcD
# AzB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmww
# HAYDVR0gBBUwEzAHBgVngQwBAzAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIB
# ADojRD2NCHbuj7w6mdNW4AIapfhINPMstuZ0ZveUcrEAyq9sMCcTEp6QRJ9L/Z6j
# fCbVN7w6XUhtldU/SfQnuxaBRVD9nL22heB2fjdxyyL3WqqQz/WTauPrINHVUHmI
# moqKwba9oUgYftzYgBoRGRjNYZmBVvbJ43bnxOQbX0P4PpT/djk9ntSZz0rdKOtf
# JqGVWEjVGv7XJz/9kNF2ht0csGBc8w2o7uCJob054ThO2m67Np375SFTWsPK6Wrx
# oj7bQ7gzyE84FJKZ9d3OVG3ZXQIUH0AzfAPilbLCIXVzUstG2MQ0HKKlS43Nb3Y3
# LIU/Gs4m6Ri+kAewQ3+ViCCCcPDMyu/9KTVcH4k4Vfc3iosJocsL6TEa/y4ZXDlx
# 4b6cpwoG1iZnt5LmTl/eeqxJzy6kdJKt2zyknIYf48FWGysj/4+16oh7cGvmoLr9
# Oj9FpsToFpFSi0HASIRLlk2rREDjjfAVKM7t8RhWByovEMQMCGQ8M4+uKIw8y4+I
# Cw2/O/TOHnuO77Xry7fwdxPm5yg/rBKupS8ibEH5glwVZsxsDsrFhsP2JjMMB0ug
# 0wcCampAMEhLNKhRILutG4UI4lkNbcoFUCvqShyepf2gpx8GdOfy1lKQ/a+FSCH5
# Vzu0nAPthkX0tGFuv2jiJmCG6sivqf6UHedjGzqGVnhOMIIGwjCCBKqgAwIBAgIQ
# BUSv85SdCDmmv9s/X+VhFjANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTIzMDcxNDAw
# MDAwMFoXDTM0MTAxMzIzNTk1OVowSDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMzCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKNTRYcdg45brD5UsyPgz5/X
# 5dLnXaEOCdwvSKOXejsqnGfcYhVYwamTEafNqrJq3RApih5iY2nTWJw1cb86l+uU
# UI8cIOrHmjsvlmbjaedp/lvD1isgHMGXlLSlUIHyz8sHpjBoyoNC2vx/CSSUpIIa
# 2mq62DvKXd4ZGIX7ReoNYWyd/nFexAaaPPDFLnkPG2ZS48jWPl/aQ9OE9dDH9kgt
# XkV1lnX+3RChG4PBuOZSlbVH13gpOWvgeFmX40QrStWVzu8IF+qCZE3/I+PKhu60
# pCFkcOvV5aDaY7Mu6QXuqvYk9R28mxyyt1/f8O52fTGZZUdVnUokL6wrl76f5P17
# cz4y7lI0+9S769SgLDSb495uZBkHNwGRDxy1Uc2qTGaDiGhiu7xBG3gZbeTZD+BY
# QfvYsSzhUa+0rRUGFOpiCBPTaR58ZE2dD9/O0V6MqqtQFcmzyrzXxDtoRKOlO0L9
# c33u3Qr/eTQQfqZcClhMAD6FaXXHg2TWdc2PEnZWpST618RrIbroHzSYLzrqawGw
# 9/sqhux7UjipmAmhcbJsca8+uG+W1eEQE/5hRwqM/vC2x9XH3mwk8L9CgsqgcT2c
# kpMEtGlwJw1Pt7U20clfCKRwo+wK8REuZODLIivK8SgTIUlRfgZm0zu++uuRONhR
# B8qUt+JQofM604qDy0B7AgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8EBAMCB4AwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNVHSAEGTAXMAgG
# BmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2FL3MpdpovdYxq
# II+eyG8wHQYDVR0OBBYEFKW27xPn783QZKHVVqllMaPe1eNJMFoGA1UdHwRTMFEw
# T6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRH
# NFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsGAQUFBwEBBIGD
# MIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wWAYIKwYB
# BQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQEL
# BQADggIBAIEa1t6gqbWYF7xwjU+KPGic2CX/yyzkzepdIpLsjCICqbjPgKjZ5+PF
# 7SaCinEvGN1Ott5s1+FgnCvt7T1IjrhrunxdvcJhN2hJd6PrkKoS1yeF844ektrC
# QDifXcigLiV4JZ0qBXqEKZi2V3mP2yZWK7Dzp703DNiYdk9WuVLCtp04qYHnbUFc
# jGnRuSvExnvPnPp44pMadqJpddNQ5EQSviANnqlE0PjlSXcIWiHFtM+YlRpUurm8
# wWkZus8W8oM3NG6wQSbd3lqXTzON1I13fXVFoaVYJmoDRd7ZULVQjK9WvUzF4UbF
# KNOt50MAcN7MmJ4ZiQPq1JE3701S88lgIcRWR+3aEUuMMsOI5ljitts++V+wQtaP
# 4xeR0arAVeOGv6wnLEHQmjNKqDbUuXKWfpd5OEhfysLcPTLfddY2Z1qJ+Panx+VP
# NTwAvb6cKmx5AdzaROY63jg7B145WPR8czFVoIARyxQMfq68/qTreWWqaNYiyjvr
# moI1VygWy2nyMpqy0tg6uLFGhmu6F/3Ed2wVbK6rr3M66ElGt9V/zLY4wNjsHPW2
# obhDLN9OTH0eaHDAdwrUAuBcYLso/zjlUlrWrBciI0707NMX+1Br/wd3H3GXREHJ
# uEbTbDJ8WC9nR2XlG3O2mflrLAZG70Ee8PBf4NvZrZCARK+AEEGKMIIHWzCCBUOg
# AwIBAgIQCLGfzbPa87AxVVgIAS8A6TANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0
# IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0Ex
# MB4XDTIzMTExNTAwMDAwMFoXDTI2MTExNzIzNTk1OVowYzELMAkGA1UEBhMCR0Ix
# FDASBgNVBAcTC1doaXRsZXkgQmF5MR4wHAYDVQQKExVBTkRSRVdTVEFZTE9SLkNP
# TSBMVEQxHjAcBgNVBAMTFUFORFJFV1NUQVlMT1IuQ09NIExURDCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBAMOkYkLpzNH4Y1gUXF799uF0CrwW/Lme676+
# C9aZOJYzpq3/DIa81oWv9b4b0WwLpJVu0fOkAmxI6ocu4uf613jDMW0GfV4dRodu
# tryfuDuit4rndvJA6DIs0YG5xNlKTkY8AIvBP3IwEzUD1f57J5GiAprHGeoc4Utt
# zEuGA3ySqlsGEg0gCehWJznUkh3yM8XbksC0LuBmnY/dZJ/8ktCwCd38gfZEO9UD
# DSkie4VTY3T7VFbTiaH0bw+AvfcQVy2CSwkwfnkfYagSFkKar+MYwu7gqVXxrh3V
# /Gjval6PdM0A7EcTqmzrCRtvkWIR6bpz+3AIH6Fr6yTuG3XiLIL6sK/iF/9d4U2P
# iH1vJ/xfdhGj0rQ3/NBRsUBC3l1w41L5q9UX1Oh1lT1OuJ6hV/uank6JY3jpm+Of
# Z7YCTF2Hkz5y6h9T7sY0LTi68Vmtxa/EgEtG6JVNVsqP7WwEkQRxu/30qtjyoX8n
# zSuF7TmsRgmZ1SB+ISclejuqTNdhcycDhi3/IISgVJNRS/F6Z+VQGf3fh6ObdQLV
# woT0JnJjbD8PzJ12OoKgViTQhndaZbkfpiVifJ1uzWJrTW5wErH+qvutHVt4/sEZ
# AVS4PNfOcJXR0s0/L5JHkjtM4aGl62fAHjHj9JsClusj47cT6jROIqQI4ejz1slO
# oclOetCNAgMBAAGjggIDMIIB/zAfBgNVHSMEGDAWgBRoN+Drtjv4XxGG+/5hewiI
# ZfROQjAdBgNVHQ4EFgQU0HdOFfPxa9Yeb5O5J9UEiJkrK98wPgYDVR0gBDcwNTAz
# BgZngQwBBAEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5jb20v
# Q1BTMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzCBtQYDVR0f
# BIGtMIGqMFOgUaBPhk1odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDBToFGg
# T4ZNaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29k
# ZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcmwwgZQGCCsGAQUFBwEBBIGH
# MIGEMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXAYIKwYB
# BQUHMAKGUGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNIQTM4NDIwMjFDQTEuY3J0MAkGA1UdEwQC
# MAAwDQYJKoZIhvcNAQELBQADggIBAEkRh2PwMiyravr66Zww6Pjl24KzDcGYMSxU
# KOEU4bykcOKgvS6V2zeZIs0D/oqct3hBKTGESSQWSA/Jkr1EMC04qJHO/Twr/sBD
# CDBMtJ9XAtO75J+oqDccM+g8Po+jjhqYJzKvbisVUvdsPqFll55vSzRvHGAA6hjy
# DyakGLROcNaSFZGdgOK2AMhQ8EULrE8Riri3D1ROuqGmUWKqcO9aqPHBf5wUwia8
# g980sTXquO5g4TWkZqSvwt1BHMmu69MR6loRAK17HvFcSicK6Pm0zid1KS2z4ntG
# B4Cfcg88aFLog3ciP2tfMi2xTnqN1K+YmU894Pl1lCp1xFvT6prm10Bs6BViKXfD
# fVFxXTB0mHoDNqGi/B8+rxf2z7u5foXPCzBYT+Q3cxtopvZtk29MpTY88GHDVJsF
# MBjX7zM6aCNKsTKC2jb92F+jlkc8clCQQnl3U4jqwbj4ur1JBP5QxQprWhwde0+M
# ifDVp0vHZsVZ0pnYMCKSG5bUr3wOU7EP321DwvvEsTjCy/XDgvy8ipU6w3GjcQQF
# mgp/BX/0JCHX+04QJ0JkR9TTFZR1B+zh3CcK1ZEtTtvuZfjQ3viXwlwtNLy43vbe
# 1J5WNTs0HjJXsfdbhY5kE5RhyfaxFBr21KYx+b+evYyolIS0wR6New6FqLgcc4Ge
# 94yaYVTqMYIGUzCCBk8CAQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgQ29kZSBT
# aWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExAhAIsZ/Ns9rzsDFVWAgBLwDp
# MA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwLwYJKoZIhvcNAQkEMSIEIIeKgWgMqhqylwyiof7FEYheyVAWIVEG6pMT
# dd4wJl0yMA0GCSqGSIb3DQEBAQUABIICAKUsmmeaCLKODw/SZ9c4T85avOAK4pVP
# /0y2V71lm1efoI8LnU+5X1+UliDtq7qf5ky6DBtfMOqxVOyLQ0duhnbjeRnrIyQ6
# d+6CYREKgW1PZ2LpVFH204cpwxikIwX7DU0RqdpgwOVV7NPQVq0bSMIQbvDpnanT
# 452n6WwVC0DlllS0yOTGXQE4Lz1cgEJESUzykuQ/2JFYr84cj3dC/sA/82kgkgDL
# zFu5Q4tlnffjw3waVPBXB9v6nlBPaHmT0P20XggV01CteWWLD/nux5X0VLwujAkx
# z3+Pmf6oNrm7Iyj+gdEH8JIuW5ej4xg8f1E9tFefwAsAz+0l7kwwCkz4YidJD0ue
# fqLfhWm0mnrV5XUJVHENI+auZf3GuriR3c/W+v5wOd7PGETEhPt9BXl4AMu8HRyE
# Db8a30LpJGZrU2FIJwBDRwEHcR16uZ9KaxGj1dN1mX75CUbqmRJaDzGt7wvfsQ0l
# uEWEJDRAyU5XJvt3EvDG6UkMbtu1+w9Rn1O0Ozvv9t0zT4AyUItJOU1vIlznZmBz
# crLeg4Acv9ulH9I3i46feBU4evGTZ4zP5J0OGlIdgdKHOhSScpML0EICYYH9tDxh
# a236j30MuTPSO6caqfCmy5IaELEZd97OnPh6q6lAaH7gZn8tmdmHSmPVVs9uJsE6
# GW15YRgsb1XVoYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkG
# A1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdp
# Q2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQ
# BUSv85SdCDmmv9s/X+VhFjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzEL
# BgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIzMTExNTIwNDcxN1owLwYJKoZI
# hvcNAQkEMSIEIFixBRsP9njo2NQdX4L3TFRaS8Hy2+1Gh7WM6HqZ/6qeMA0GCSqG
# SIb3DQEBAQUABIICAH3T+GN3M40ML1Kw3izv6UpdpFTumw948vqqxuV7QALV0QNd
# 7OF9AEYeCrCIjjDO7zOovffK+CoXngPyaqPf9huJ2L0ypOyLl2StPL5pe5p+OfHg
# Ppg9bFnGx0uzZesElnfOUe/0rqN0b/DU/CoWULa5lqKjyj7OWOj/qGj1i6VDg/Qx
# tml0Eeiq9jPfvp1drMKkE60HhibQC2eFFngVu50tiRjTDFg7/bNEIauXfDtp/kky
# JzDiTPAQd3ptZZoSccYjWp2sNig+638Ex13UzVg78ObBSS/eHM+fu096a73BcmTA
# bXSwEh1PxIEQSKQfURY+w1ZAYSeAEf68h/nQEsExKMPXwcBLh1nEr+O/P1YdhWAY
# 2pNEsRzRPDiY5oG7c9ae/4kk06nYyoqn6kfj3zabXtkSFpXyJ+hKI8sitGHLtPaa
# KROT1s5LfzeEcDwkI4gf/2l21b3hgO0uBXuXtFZWVRbZWjS7/Fa/V/p9Cetqeib0
# Zyk1t6tjmuy7HTRMknO+G6UefmMnoZpcC6/8DBcF3bmhu8mw/RsJt6ffgT32UKM3
# 1ViM5VeZk4F7NouMvtYX7rG2KJOVRYsl46ZkIKI3UM3UUEOfBNI3U+vWww7dRJjo
# /NiPNPbmy6sNNZIR2ceUKOeZcsJlFCnYgS94MpgFPOgw+WNA4pY9TlikrBxw
# SIG # End signature block
