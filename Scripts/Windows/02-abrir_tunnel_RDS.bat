@ echo off
cls

echo.
set /P instance_id=Instance_ID de ponte:
set /P endpoint_rds=Endpoint do RDS:
set /P portAWS=Porta do banco na aws:
set /P portLocal=Porta local a redirecionar:
echo ============================================================================
echo OBS.: Mantenha esse terminal aberto e para acessar o BANCO DE DADOS coloque:
echo Em address: localhost e em Port: %portLocal% no PGAdmin, Workbench, DBeaver...
echo ============================================================================
echo.

aws ssm start-session --target %instance_id% --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters "{\"host\":[\"%endpoint_rds%\"],\"portNumber\":[\"%portAWS%\"], \"localPortNumber\":[\"%portLocal%\"]}"