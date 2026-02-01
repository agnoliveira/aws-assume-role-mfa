#!/bin/bash

clear
echo

# Pergunta os parâmetros
read -p "Instance_ID de ponte: " instance_id
read -p "Endpoint do RDS:" endpoint_rds
read -p "Porta do banco na aws: " portAWS
read -p "Porta local a redirecionar:" portLocal

echo ============================================================================
echo OBS.: Mantenha esse terminal aberto e para acessar o BANCO DE DADOS coloque:
echo Em address: localhost e em Port: $portLocal no PGAdmin, Workbench, DBeaver...
echo ============================================================================

# Executa a sessão do SSM com port forwarding
aws ssm start-session \
  --target "$instance_id" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$endpoint_rds\"],\"portNumber\":[\"$portAWS\"], \"localPortNumber\":[\"$portLocal\"]}"