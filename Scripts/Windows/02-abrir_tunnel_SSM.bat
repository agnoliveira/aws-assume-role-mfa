@ echo off
cls

echo.
set /P instance_id=Instance_ID: 
set /P portAWS=Porta SSH ou RDP na aws:
set /P portLocal=Porta SSH ou RDP local:
echo.
echo =================================================================
echo OBS.: Mantenha esse terminal aberto e para acessar a EC2 coloque:
echo localhost:%portLocal% em seu APP de acesso ao linux ou windows
echo =================================================================
echo.
aws ssm start-session --target %instance_id% --document-name AWS-StartPortForwardingSession --parameters "{\"portNumber\":[\"%portAWS%\"],\"localPortNumber\":[\"%portLocal%\"]}"