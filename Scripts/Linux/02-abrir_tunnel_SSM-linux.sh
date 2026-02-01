#!/bin/bash

clear
echo

# Pergunta os parâmetros
read -p "Instance_ID: " instance_id
read -p "Porta ssh ou rdp na aws: " portAWS
read -p "Porta ssh ou rdp local:" portLocal

# Define valores padrão se o usuário não digitar nada
portAWS=${portAWS:-22}
portLocal=${portLocal:-22}

echo =================================================================
echo OBS.: Mantenha esse terminal aberto e para acessar a EC2 coloque:
echo localhost:$portLocal em seu APP de acesso ao linux ou windows
echo =================================================================

# Executa a sessão do SSM com port forwarding
aws ssm start-session \
  --target "$instance_id" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"$portAWS\"],\"localPortNumber\":[\"$portLocal\"]}"
