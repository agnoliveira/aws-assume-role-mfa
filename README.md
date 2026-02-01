# Automação segura de AssumeRole na AWS com MFA para acesso Same-Account e Cross-Account usando Bash e PowerShell.

## Objetivo

Permitir acesso seguro à AWS utilizando:

- MFA obrigatório
- AssumeRole via STS
- Suporte a:
  - Same-Account
  - Cross-Account
- Abrir tunnel SSM para acessar RDS e EC2 em redes privadas com segurança

## Pré-requisitos:

### Windows

Download AWS CLI (v2)

```
https://awscli.amazonaws.com/AWSCLIV2.msi
```

Session Manager Plugin (SSM)

```
https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe
```

### Linux (Ubuntu)

Download AWS CLI (v2)

```
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Session Manager Plugin (SSM)

```
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

Dependência jq para processar a saída JSON retornada pelo AWS CLI (STS AssumeRole):

```
sudo apt update
sudo apt install -y jq
```

# Preparando o ambiente

## Cenário 1 - Same-Account (configurando o assume role na mesma conta):

- Passo 01 - Crie um usuário no IAM "user_teste"e NÃO anexe nenhuma permissão e copie o ARN dele: arn:aws:iam::ID-CONTA-PRINCIPAL:user/user_teste
- Passo 02 - Crie uma Role no IAM do tipo AWS Account, flag ***"This Account(ID-CONTA-PRIMARIA)"*** e flag também ***"Require MFA"***
    - Em permissões, coloque a permissão que deseja que o usuário execute ***(por boas práticas, colocar sempre a menos restritiva possivel)***  
    - Role name: user_teste-role ***(coloque sempre o nome do usuário e acrescente -role, senão o script não irá funcionar)***
- Passo 03 - Após criar a Role, localize a mesma em Roles, abra ela e na aba Trust relationship clique em editar, devemos colocar o ARN do usuário criado, tirando o root, exemplo abaixo:

### Trust policy da role: user_teste-role ***(trocar o id da conta)***
```
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"AWS": "arn:aws:iam::ID-CONTA-PRINCIPAL:user/user_teste"
			},
			"Action": "sts:AssumeRole",
			"Condition": {
				"Bool": {
					"aws:MultiFactorAuthPresent": "true"
				}
			}
		}
	]
}   
```

***Ao criar a role, ela tem um padrão de tempo de sessão de 1h, podendo ser alterada para mais (importante para poder definir o tempo máximo ao utilizar os scripts abaixo)***

## Criando o MFA
Em IAM\Users, localize o usuário criado ***user_teste*** e edite, na aba ***security credentials*** clique em Assign MFA device, de um nome e escolha o método de autenticação de sua preferencia. Utilizo o Authenticator app com o Google Authenticator

## Cenário 2 - Across-Account (configurando o assume role em outra conta):

### Conta principal:

- Passo 01 - Crie um usuário no IAM ***"user_teste"*** e NÃO anexe nenhuma permissão ***(faremos depois)*** e copie o ARN dele: arn:aws:iam::ID-CONTA-PRINCIPAL:user/user_teste
- Passo 02 - Vá na conta secundária e siga o ***passo 04*** e depois continue aqui...
    - Crie uma Policy ***"user_teste-policy"*** no IAM permitindo que o usuario possa assumir a role que estará na outra conta, segue o json da policy já com o ARN criado no ***passo 04***: "arn:aws:iam::ID-CONTA-SECUNDARIA:role/user_teste-role"

### JSON Policy: user_teste-policy  
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::ID-CONTA-SECUNDARIA:role/user_teste-role"
        }
    ]
}
```

Passo 03 - Anexe a policy criada ***"user_teste-policy"*** no usuário criado no passo 01

### Conta secundária:

- Passo 04 - Crie uma Role no IAM do tipo AWS Account, flag ***"Another AWS account"*** e flag também ***"Require MFA"***, em ***"Account ID"***, coloque o ID-CONTA-PRINCIPAL
    - Em permissões, coloque a permissão que deseja que o usuário execute ***(por boas práticas, colocar sempre a menos restritiva possivel)***
    - Role name: user_teste-role ***(coloque sempre o nome do usuário e acrescente -role, senão o script não irá funcionar)***
    - Após criar a Role, localize a mesma e abra, vá na aba Trust relationship e clique em editar, devemos colocar o ARN do usuário criado, tirando o root, exemplo abaixo:

### Trust policy da role: user_teste-role ***(trocar o id da conta)***
```
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"AWS": "arn:aws:iam::ID-CONTA-PRINCIPAL:user/user_teste"
			},
			"Action": "sts:AssumeRole",
			"Condition": {
				"Bool": {
					"aws:MultiFactorAuthPresent": "true"
				}
			}
		}
	]
}   
```  

- Copie o ARN da role criada e volte na conta pricipal no passo 02 para continuar: "arn:aws:iam::ID-CONTA-SECUNDARIA:role/user_teste-role"

## Criando o MFA
Em IAM\Users, localize o usuário criado ***user_teste*** e edite, na aba ***security credentials*** clique em Assign MFA device, de um nome e escolha o método de autenticação de sua preferencia. Utilizo o Authenticator app com o Google Authenticator

# Utilizando os scripts

*** OBS.: Ao rodar, tanto o Powershell, quanto o terminal linux, tem que ficar aberto, pois as credenciais ficam somente na sessão aberta, ao fechar as credenciais se perdem.

### Windows

#### Scripts/Windows/01-credencial_e_assume_role.ps1
> Para executar, abra o powershell, localize a pasta onde se encontra o script e execute:  
>
```
. '.\01-credencial_e_assume_role.ps1'
```
>
> Escolha as opções conforme solicitado
> 
> 1 - Same-Account (Assume uma role que esta na mesma conta)  
> 2 - Cross-Account (Assume uma role que esta em outra conta)
>
> Access Key ID (do usuario onde esta o MFA):  
> Secret Access Key (do usuario onde esta o MFA):  
> Regiao (Padrao = us-east-1):  
> ACCOUNT ID (Conta AWS secundaria onde esta a ROLE que ira assumir): (Só aparece se escolher a opção 2 no passo anterior)  
> Nome do usuario:  
> Identificador MFA (colocar somente do / em diante nao precisa do arn todo):  
> Codigo MFA (6 digitos):

#### ***Com esse processo, já podemos executar o AWS Cli ou usar o Terraform por exemplo***, caso queria abrir um tunel para se conectar a um RDS ou acessar uma EC2 que esteja em zona privada, siga abaixo os scripts:

#### Scripts/Windows/02-abrir_tunnel_RDS.bat

> Para executar, abra o powershell, localize a pasta onde se encontra o script e execute:  
>
```
. '.\02-abrir_tunnel_RDS.bat'
```
> Escolha as opções conforme solicitado

#### Scripts/Windows/02-abrir_tunnel_SSM.bat

> Para executar, abra o powershell, localize a pasta onde se encontra o script e execute:  
>
```
. '.\02-abrir_tunnel_SSM.bat'
```
> Escolha as opções conforme solicitado

### Linux  
Segue os mesmos passos do windows, mudando somente do Powershell, pelo terminal