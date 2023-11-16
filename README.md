# Pipeline de Dados com AWS

## Índice

- [Sobre](#sobre)
- [Como Rodar o Projeto](#run)
<br>

## Sobre <a name = "sobre"></a>

Esse projeto tem como objetivo criar caso de uso de uma pipeline de dados simples que utilize as ferramentas AWS, Terraform, Python, Airflow, Postgres e Power BI.
<br>

## Como Rodar o Projeto <a name = "run"></a>

### Requisitos
 - <a href="https://aws.amazon.com/pt/free/?trk=16c88e2f-f4a2-4df9-a8da-5cec9a840180&sc_channel=ps&ef_id=Cj0KCQjwy9-kBhCHARIsAHpBjHgoBuCsAGz5KbOD-mBqkU-pjhss27HIyogO5NptoI4K8hKOtHVkpkMaAms4EALw_wcB:G:s&s_kwcid=AL!4422!3!659757281492!e!!g!!conta%20da%20aws!20187397673!152493143234&all-free-tier.sort-by=item.additionalFields.SortRank&all-free-tier.sort-order=asc&awsf.Free%20Tier%20Types=*all&awsf.Free%20Tier%20Categories=*all">Conta AWS</a>
  - <a href="https://developer.hashicorp.com/terraform/downloads?product_intent=terraform">Terraform</a>
  - <a href="https://www.postgresql.org/download/">PostgreSQL</a>
  - <a href="https://airflow.apache.org/">Airflow</a>
- <a href="https://powerbi.microsoft.com/pt-br/landing/free-account/?ef_id=_k_Cj0KCQjwy9-kBhCHARIsAHpBjHgXvtqDiWjvWJn-ef6tK6aXC7WwkVPw8FhtNFNEr-rM4M2ZU9wLwWQaApLhEALw_wcB_k_&OCID=AIDcmmk4cy2ahx_SEM__k_Cj0KCQjwy9-kBhCHARIsAHpBjHgXvtqDiWjvWJn-ef6tK6aXC7WwkVPw8FhtNFNEr-rM4M2ZU9wLwWQaApLhEALw_wcB_k_&gclid=Cj0KCQjwy9-kBhCHARIsAHpBjHgXvtqDiWjvWJn-ef6tK6aXC7WwkVPw8FhtNFNEr-rM4M2ZU9wLwWQaApLhEALw_wcB">Power BI</a>

A primeira tarefa a ser feita é criar o banco de dados onde ficara armazenado os dados tratados e criar os usuarios necessários. Para isso, conecte ao banco de dados PostgreSQL e execute os comandos SQL do arquivo <b>criar_OLAP_database.sql</b> localizado na pasta <b>dados</b>.

<br>

Em seguida, crie <a href="https://docs.aws.amazon.com/pt_br/toolkit-for-visual-studio/latest/user-guide/keys-profiles-credentials.html">Chaves de Acesso </a> para sua conta AWS, com as credenciais em mãos, crie variaveis de ambiente temporarias com as informações adquiridas:
#### WINDOWS ( PowerShell )
```
$env:AWS_ACCESS_KEY_ID="minhachavedeacesso"
$env:AWS_SECRET_ACCESS_KEY="minhachavesecreta"
```

#### LINUX / MAC
```
export AWS_ACCESS_KEY_ID=minhachavedeacesso
export AWS_SECRET_ACCESS_KEY=minhachavesecreta
```

<br>

Com o Terraform instalado, na pasta chamada <b>terraform</b> do projeto execute no terminal o comando: 
```
terraform init
```
Esse comando inicializar diretório de trabalho que contem arquivos de configuração do Terraform.

<br>

Em seguida, para provisionar a infraestrutura necessária para o projeto, execute o comando:
```
terraform apply
```

<br>

Após a finalização do provisionamento da infraestrutura, execute:
```
terraform output -json
```
Esse comando mostra as saidas definidas no arquivo <b>outputs.tf</b>, nesse arquivo foi definido para mostrar o nome do bucket criado, a chave de acesso e a chave secreta do usuario, guarde essas informações<i>. (A chave secreta é um parametro sensivel, por questões de segurança o terraform normalmente não irá mostra-la, por isso é utilizado o <b>-json</b> para visualizar essa informação sensivel)</i>

Copie o arquivo <b>airflow_etl.py</b> e cole na pasta de dags do seu Airflow, configure o seu <a href="https://airflow.apache.org/docs/apache-airflow/stable/howto/email-config.html">e-mail no Airflow </a>, instale os pacotes do arquivo <b>requirements.txt</b>, por fim, crie um arquivo com o nome <b>.env</b> na mesma pasta que se encontra o <b>airflow_etl.py</b>.

Abrar o <b>.env</b> com algum editor de texto, o mesmo deverá conter a seguinte estrutura:

```
# postgres
DB_USER="airflow"
DB_PASSWORD="MyP@ssword"
DB_HOST="localhost"
DB_NAME="loan"
DB_PORT=5432

# aws
AWS_ACCESS_KEY_ID= "suachavedeacesso"
AWS_SECRET_ACCESS_KEY= "suachavesecreta"
BUCKET_NAME = "nomedobucket"

# e-mail
EMAIL = "seuemailairflow@gmail.com.br"
```

Pronto! A pipeline de dados foi construida. Depois da primeira execução da dag o usuario <i>joao</i> poderá realizar suas analises se conectando ao banco de dados pelo Power BI.
<br>

Após finalizar os testes não se esqueça de excluir a infraestrutura criada na AWS para evitar possiveis custos. Utilize o comando abaixo para excluir os recursos criados.
```
terraform destroy --auto-approve
```