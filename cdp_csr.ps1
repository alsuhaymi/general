## PowerShell Script to generate a Certificate Signing Request (CSR) using the SHA256 (SHA-256) signature algorithm and a 2048 bit key size (RSA) via the Cert Request Utility (certreq) ##

<#

.SYNOPSIS
This powershell script can be used to generate a Certificate Signing Request (CSR) using the SHA256 signature algorithm and a 2048 bit key size (RSA). Subject Alternative Names are supported.

.DESCRIPTION
Tested platforms:
- Windows Server 2008R2 with PowerShell 2.0
- Windows 8.1 with PowerShell 4.0
- Windows 10 with PowerShell 5.0

Created By:
Reinout Segers

Resource: https://pscsr256.codeplex.com

Changelog
v1.1
- Added support for Windows Server 2008R2 and PowerShell 2.0
v1.0
- initial version
#>

####################
# Prerequisite check
####################
if (-NOT([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Administrator priviliges are required. Please restart this script with elevated rights." -ForegroundColor Red
    Pause
    Throw "Administrator priviliges are required. Please restart this script with elevated rights."
}


#######################
# Setting the variables
#######################
$certBaseDir = "C:\Tools\Certificates"
$CSRDir = $certBaseDir + "\csr"
$CertsDir = $certBaseDir + "\certs"
$PfxDir = $certBaseDir + "\keys"

New-Item -Path $certBaseDir -ItemType Directory -ErrorAction 'SilentlyContinue'
New-Item -Path $CSRDir -ItemType Directory -ErrorAction 'SilentlyContinue'
New-Item -Path $CertsDir -ItemType Directory -ErrorAction 'SilentlyContinue'
New-Item -Path $PfxDir -ItemType Directory -ErrorAction 'SilentlyContinue'

$UID = [guid]::NewGuid()
$files = @{}
$files['settings'] = "$($env:TEMP)\$($UID)-settings.inf";
$files['csr'] = "$($env:TEMP)\$($UID)-csr.req"


$request = @{}
$request['SAN'] = @{}
$hostName = $args[0]

Write-Host "Provide the Subject details required for the Certificate Signing Request" -ForegroundColor Yellow
$request['CN'] = $hostName
$request['O'] = "EMEA"
$request['OU'] = "Professional Services"
$request['S'] = "Riyadh"
$request['C'] = "SA"



###########################
# Subject Alternative Names
###########################
$i = 0

# Remove the last in the array (which is empty)
$request['SAN'][$i] = $hostName

#########################
# Create the settings.inf
#########################
$settingsInf = "
[Version]
Signature=`"`$Windows NT`$
[NewRequest]
KeyLength =  4096
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
RequestType =  PKCS10
ProviderName = `"Microsoft RSA SChannel Cryptographic Provider`"
ProviderType =  12
HashAlgorithm = sha256
;Variables
Subject = `"CN={{CN}},OU={{OU}},O={{O}},L={{L}},S={{S}},C={{C}}`"
[Extensions]
{{SAN}}


;Certreq info
;http://technet.microsoft.com/en-us/library/dn296456.aspx
;CSR Decoder
;https://certlogik.com/decoder/
;https://ssltools.websecurity.symantec.com/checker/views/csrCheck.jsp
"

$request['SAN_string'] = & {
	if ($request['SAN'].Count -gt 0) {
		$san = "2.5.29.17 = `"{text}`"
"
		Foreach ($sanItem In $request['SAN'].Values) {
			$san += "_continue_ = `"dns="+$sanItem+"&`"
"
		}
		return $san
	}
}

$settingsInf = $settingsInf.Replace("{{CN}}",$request['CN']).Replace("{{O}}",$request['O']).Replace("{{OU}}",$request['OU']).Replace("{{L}}",$request['L']).Replace("{{S}}",$request['S']).Replace("{{C}}",$request['C']).Replace("{{SAN}}",$request['SAN_string'])

# Save settings to file in temp
$settingsInf > $files['settings']

#################################
# CSR TIME
#################################

# Display summary
Write-Host "Certificate information
Common name: $($request['CN'])
Organisation: $($request['O'])
Organisational unit: $($request['OU'])
City: $($request['L'])
State: $($request['S'])
Country: $($request['C'])

Subject alternative name(s): $($request['SAN'].Values -join ", ")

Signature algorithm: SHA256
Key algorithm: RSA
Key size: 4096

" -ForegroundColor Yellow

certreq -new $files['settings'] $files['csr'] > $null

# Output the CSR
$CSR = Get-Content $files['csr']
Write-Output $CSR
Write-Host "
"

# Specify the file path
$CSRPath = $CSRDir + "\" + $hostName + ".csr"

# Write the content to the file
$CSR | Set-Content -Path $CSRPath

$CertPath = $CertsDir + "\" + $hostName + ".cer"
$PfxPath = $PfxDir + "\" + $hostName + ".pfx"

certreq -q -submit -attrib "CertificateTemplate:ClouderaDataServicesTPL" $CSRPath $CertPath $PfxPath

$CertStorePath = 'Cert:\LocalMachine\My'

$params = @{
  FilePath = $CertPath
  CertStoreLocation = $CertStorePath
}

$ImportedCertificate = Import-Certificate @params

$mypwd = ConvertTo-SecureString -String '1234' -Force -AsPlainText

 Get-ChildItem -Path $CertStorePath | Sort-Object -Property NotBefore -Descending | Select-Object -first 1 |
    Export-PfxCertificate -FilePath $PfxPath -Password $mypwd

########################
# Remove temporary files
########################
$files.Values | ForEach-Object {
    Remove-Item $_ -ErrorAction SilentlyContinue
}