# recycleIISAppPool
Script criado para ser utilizado como uma automação pra realizar o recycle de um AppPool que esteja consumindo muito recurso no servidor. A ideia é ter uma ferramenta de monitoramento que ao verificar que o servidor está com um alto consulmo ou de CPU ou de memória o mesmo executa o script nesse servidor para normalizar o consumo de recurso.

Para realizar a execução remota do script, utilizar os comandos abaixo.
```powershell
# Para memória
Invoke-Command -ComputerName SERVIDOR -FilePath "Caminho_onde_se_encontra_o_Script" -ArgumentList "mem" -Credential "USUARIO"
```   
```powershell
# Para CPU
Invoke-Command -ComputerName SERVIDOR -FilePath "Caminho_onde_se_encontra_o_Script" -ArgumentList "cpu" -Credential "USUARIO"
```
