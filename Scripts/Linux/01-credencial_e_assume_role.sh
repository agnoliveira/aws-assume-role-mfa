#!/bin/bash

# =================
# CONFIGURACAO FIXA
# =================

SESSION_NAME="linux-session-manager"

# ===================
# TIPO DE ACESSO
# ===================

echo "*** TIPO DE ACESSO ***"
echo "1 - Same-Account (Assume uma role que esta na mesma conta)"
echo "2 - Cross-Account (Assume uma role que esta em outra conta)"
read ACCESS_TYPE

if [[ "$ACCESS_TYPE" != "1" && "$ACCESS_TYPE" != "2" ]]; then
  echo "Opcao invalida. Utilize 1 ou 2."
  exit 1
fi

# ===================
# INFORMAR PARAMETROS
# ===================

echo ""
echo "*** PARAMETROS ***"

echo "Access Key ID (do usuario onde esta o MFA):"
read ACCESS_KEY

echo "Secret Access Key (do usuario onde esta o MFA):"
read SECRET_ACCESS_KEY

echo "Regiao (Padrao = us-east-1)"
read REGION
REGION=${REGION:-us-east-1}

# =================
# LIMPAR VARIAVEIS
# =================

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_DEFAULT_REGION

# ==================================
# CONFIGURA AS VARIAVEIS DE AMBIENTE
# ==================================

export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$REGION

# Pega o Account_ID da chave usada acima e armazena na variável abaixo
PRINCIPAL_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Se for Cross-Account, pede a conta secundaria
if [[ "$ACCESS_TYPE" == "2" ]]; then
  echo "ACCOUNT ID (Conta AWS secundaria onde esta a ROLE que ira assumir):"
  read SECUNDARY_ACCOUNT_ID
fi

# ==========================
# ENTRADAS PARA ASSUME_ROLE
# ==========================

echo "Nome do usuario:"
read USER_NAME

ROLE_ARN="arn:aws:iam::$PRINCIPAL_ACCOUNT_ID:role/$USER_NAME-role"
ROLE_ARN2="arn:aws:iam::$SECUNDARY_ACCOUNT_ID:role/$USER_NAME-role"

echo "Identificador MFA (colocar somente do / em diante nao precisa do arn todo):"
read MFA_IDENTIFIER

# ARN do PRINCIPAL MFA
MFA_SERIAL_ARN="arn:aws:iam::$PRINCIPAL_ACCOUNT_ID:mfa/$MFA_IDENTIFIER"

echo "Codigo MFA (6 digitos):"
read MFA_CODE

echo "Informe a duracao em segundos (Padrao = 900 = 15min):"
read ASSUME_ROLE_DURATION
ASSUME_ROLE_DURATION=${ASSUME_ROLE_DURATION:-900}

# ==================================================
# ASSUME A ROLE E CAPTURA AS CREDENCIAIS TEMPORARIAS
# ==================================================

# Define qual ROLE_ARN usar com base single 
if [[ "$ACCESS_TYPE" == "1" ]]; then
  ROLE_ARN_PARAM="$ROLE_ARN"
else
  ROLE_ARN_PARAM="$ROLE_ARN2"
fi

CREDENTIALS_JSON=$(aws sts assume-role \
  --role-arn "$ROLE_ARN_PARAM" \
  --role-session-name "$SESSION_NAME" \
  --serial-number "$MFA_SERIAL_ARN" \
  --token-code "$MFA_CODE" \
  --duration-seconds "$ASSUME_ROLE_DURATION")

echo "$CREDENTIALS_JSON"

# ==================================
# CONFIGURA AS VARIAVEIS DE AMBIENTE
# ==================================

export AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS_JSON" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS_JSON" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDENTIALS_JSON" | jq -r '.Credentials.SessionToken')
export AWS_SESSION_EXPIRATION=$(echo "$CREDENTIALS_JSON" | jq -r '.Credentials.Expiration')

echo ""
echo "Assume Role concluido com sucesso."

# =========
# VALIDACAO
# =========

echo ""
echo "Identidade AWS atual:"
echo ""
aws sts get-caller-identity

# ===============
# INFORMACAO UTIL
# ===============

EXPIRATION_LOCAL=$(TZ=UTC date -d "$AWS_SESSION_EXPIRATION -3 hours" "+%d-%m-%Y %H:%M:%S")

echo ""
echo "Credenciais expiram em: $EXPIRATION_LOCAL (UTC-3)"
echo ""
echo "Pronto para uso com AWS CLI / Terraform."
