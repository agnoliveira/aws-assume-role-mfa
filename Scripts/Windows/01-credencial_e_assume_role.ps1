# =================
# CONFIGURACAO FIXA
# =================

$SESSION_NAME = "ps-session-manager"

# ===================
# TIPO DE ACESSO
# ===================

Write-Host "*** TIPO DE ACESSO ***"
Write-Host "1 - Same-Account (Assume uma role que esta na mesma conta)"
Write-Host "2 - Cross-Account (Assume uma role que esta em outra conta)"
$ACCESS_TYPE = Read-Host

if ($ACCESS_TYPE -ne "1" -and $ACCESS_TYPE -ne "2") {
    Write-Host "Opcao invalida. Utilize 1 ou 2."
    exit 1
}

# ===================
# INFORMAR PARAMETROS
# ===================

Write-Host ""
Write-Host "*** PARAMETROS ***"

$ACCESS_KEY = Read-Host "Access Key ID (do usuario onde esta o MFA)"
$SECRET_ACCESS_KEY = Read-Host "Secret Access Key (do usuario onde esta o MFA)"

$REGION = Read-Host "Regiao (Padrao = us-east-1)"
if ([string]::IsNullOrEmpty($REGION)) {
    $REGION = "us-east-1"
}

# =================
# LIMPAR VARIAVEIS
# =================

Remove-Item Env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
Remove-Item Env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
Remove-Item Env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:AWS_DEFAULT_REGION -ErrorAction SilentlyContinue

# ==================================
# CONFIGURA AS VARIAVEIS DE AMBIENTE
# ==================================

$Env:AWS_ACCESS_KEY_ID     = $ACCESS_KEY
$Env:AWS_SECRET_ACCESS_KEY = $SECRET_ACCESS_KEY
$Env:AWS_DEFAULT_REGION   = $REGION

# Pega o Account_ID da chave usada acima e armazena na variável abaixo
$PRINCIPAL_ACCOUNT_ID = (aws sts get-caller-identity | ConvertFrom-Json).Account

# Se for Cross-Account, pede a conta secundaria
if ($ACCESS_TYPE -eq "2") {
    $SECUNDARY_ACCOUNT_ID = Read-Host "ACCOUNT ID (Conta AWS secundaria onde esta a ROLE que ira assumir)"
}

# ==========================
# ENTRADAS PARA ASSUME_ROLE
# ==========================

$USER_NAME = Read-Host "Nome do usuario"

$ROLE_ARN  = "arn:aws:iam::${PRINCIPAL_ACCOUNT_ID}:role/${USER_NAME}-role"
$ROLE_ARN2 = "arn:aws:iam::${SECUNDARY_ACCOUNT_ID}:role/${USER_NAME}-role"

$MFA_IDENTIFIER = Read-Host "Identificador MFA (colocar somente do / em diante nao precisa do arn todo)"

# ARN do PRINCIPAL MFA
$MFA_SERIAL_ARN = "arn:aws:iam::${PRINCIPAL_ACCOUNT_ID}:mfa/${MFA_IDENTIFIER}"

$MFA_CODE = Read-Host "Codigo MFA (6 digitos)"

$ASSUME_ROLE_DURATION = Read-Host "Informe a duracao em segundos (Padrao = 900 = 15min)"
if ([string]::IsNullOrEmpty($ASSUME_ROLE_DURATION)) {
    $ASSUME_ROLE_DURATION = 900
}

# ==================================================
# ASSUME A ROLE E CAPTURA AS CREDENCIAIS TEMPORARIAS
# ==================================================

# Define qual ROLE_ARN usar com base no tipo de acesso
if ($ACCESS_TYPE -eq "1") {
    $ROLE_ARN_PARAM = $ROLE_ARN
} else {
    $ROLE_ARN_PARAM = $ROLE_ARN2
}

$CREDENTIALS_JSON = aws sts assume-role `
    --role-arn $ROLE_ARN_PARAM `
    --role-session-name $SESSION_NAME `
    --serial-number $MFA_SERIAL_ARN `
    --token-code $MFA_CODE `
    --duration-seconds $ASSUME_ROLE_DURATION | ConvertFrom-Json

$CREDENTIALS_JSON | ConvertTo-Json -Depth 5

# ==================================
# CONFIGURA AS VARIAVEIS DE AMBIENTE
# ==================================

$Env:AWS_ACCESS_KEY_ID     = $CREDENTIALS_JSON.Credentials.AccessKeyId
$Env:AWS_SECRET_ACCESS_KEY = $CREDENTIALS_JSON.Credentials.SecretAccessKey
$Env:AWS_SESSION_TOKEN    = $CREDENTIALS_JSON.Credentials.SessionToken
$Env:AWS_SESSION_EXPIRATION = $CREDENTIALS_JSON.Credentials.Expiration

Write-Host ""
Write-Host "Assume Role concluido com sucesso."

# =========
# VALIDACAO
# =========

Write-Host ""
Write-Host "Identidade AWS atual:"
Write-Host ""
aws sts get-caller-identity

# ===============
# INFORMACAO UTIL
# ===============

$EXPIRATION_LOCAL = [datetime]::ParseExact(
    $Env:AWS_SESSION_EXPIRATION,
    "dd/MM/yyyy HH:mm:ss",
    [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR")
)

Write-Host ""
Write-Host "Credenciais expiram em: $($EXPIRATION_LOCAL.ToString('dd-MM-yyyy HH:mm:ss')) (UTC-3)"
Write-Host ""
Write-Host "Pronto para uso com AWS CLI / Terraform."

