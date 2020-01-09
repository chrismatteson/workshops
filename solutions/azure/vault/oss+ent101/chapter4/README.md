## Chapter 4 Solutions

* Enable userpass auth
`vault auth enable userpass`<br>
`vault write auth/userpass/users/mitchellh password=foo`<br>

* Enable azure auth
`vault auth enable azure`<br>
`vault write auth/azure/config \<br>
  tenant_id=${data.azurerm_client_config.current.tenant_id} \<br>
  resource=https://management.azure.com \<br>
  client_id=${azuread_application.vaultapp.application_id} \<br>
  client_secret=${azuread_service_principal_password.vaultapp.value}`<br>

* Access Identity token
curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com' -H Metadata:true
