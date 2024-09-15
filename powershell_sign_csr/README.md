# Pre-reqs
Create a Certificate Template with the following props:
- keyUsage = nonRepudiation, digitalSignature, keyEncipherment
- extendedKeyUsage = serverAuth, clientAuth
- subjectAltName = Provided by CSR

# Configuration
- Edit the script to change the path $certBaseDir = "C:\Tools\Certificates" (line 39)
- Change the Certificate Template name to the one created above : ClouderaDataServicesTPL (line 159)

# Usage
```powershell
.\cdp_csr.ps1 <server name>
...
...
.\cdp_csr.ps1 <server name>
```
