# --------------------------------------------------------------- #
# recycleIIS.ps1                                                  #
# --------------------------------------------------------------- #
# Autor: Daniel Noronha da Silva                                  #
# --------------------------------------------------------------- #
# Descrição:                                                      #
#   O Scrip irá verificar qual POOL do WebService está consumindo #
#   mais recurso, Memória ou CPU, e irá realizar um Recycle nesse #
#   POOL para normalizar a utilização de recursos no servidor.    #
# --------------------------------------------------------------- #
# Changelog:                                                      #
#   v0.1 - Daniel Noronha - 11/07/2022                            #
#     - Criado as funções abaixo para a correta execução do       #
#       Recycle quando o recurso for utilização de memória.       #
#       - verificaArquivosDeLog                                   #
#       - gravaLog                                                #
#       - pegaProcessoDoIISComMaiorUsoDeMemoria                   #
#       - recyclePorMemoria                                       #
#       - pegaMemoriaAposRecycle                                  #
#       - main                                                    #
#   v0.2 - Daniel Noronha - 11/07/2022                            #
#     - Criado as funções abaixo para a correta execução do       #
#       Recycle quando o recurso for utilização de CPU.           #
#       - pegaProcessosdoIISComMaiorUsoDeCpu                      #
#       - recyclePorCPU                                           #
#       - pegaCPUAposRecycle                                      #
#   v0.3 - Daniel Noronha - 12/07/2022                            #
#     - Alterado o diretório do log                               #
#     - Alterado o nome do arquivo de log, o mesmo agora será     #
#       criado informando a data no nome do arquivo.              #
#     - Criado a função validaRecycle para verificar se o consumo #
#       foi normalizado após o Recycle, se sim, o mesmo irá       #
#       alterar o valor da variável $statusExecucao para Sucesso! #
#       e irá gravar no LOG que o Recycle para o POOL XPTO foi    #
#       executado com sucesso.                                    #
#   v0.4 - Daniel Noronha - 13/07/2022                            #
#     - Retirado as funções referente ao Recycle por CPU. Essas   #
#       funções foram movidas para o arquivo recycleISSPorCPU.ps1.#
#   v0.5 - Daniel Noronha 13/07/2022                              #
#     - Criado a função pegaPorcentagemDeUsoMemoria para que possa#
#       ser validado se o percentual de uso foi abaixado após o   #
#       Recycle.                                                  #
#   v0.6 - Daniel Noronha 15/07/2022                              #
#     - Unificando os scripts de memória e CPU para um único      #
#       arquivo.                                                  #
#     - Adicionado as funções abaixo:                             #
#       - pegaProcessosdoIISComMaiorUsoDeCpu                      #
#       - recyclePorCPU                                           #
#       - pegaCPUAposRecycle                                      #
#       - validaRecycle                                           #
# --------------------------------------------------------------- #
# Versão Atual: v0.6                                              #
# --------------------------------------------------------------- #

# --- VÁRIAVEIS ------------------------------------------------- #
$componente = $args[0].ToUpper()
$hostName = hostname
$data = (Get-Date -UFormat "%d-%m-%Y")
$diretorioLog = ""
$arquivoLog = "recycleIIS-${componente}-${hostName}-${data}.log"
$tempoDeEspera = 20
# --------------------------------------------------------------- #

# --- FUNÇÕES --------------------------------------------------- #

# -- Para Memória
function verificaArquivosDeLog {
  # Verificando se o diretório de log existe, se não
  # o mesmo será criado.
  if ( -not ( Test-Path $diretorioLog) ) {
    New-Item -Path $diretorioLog -ItemType Directory
    "Diretório '$diretorioLog' criado com sucesso."
  }

  # Verificando se o arquivo de log existe, se não
  # o mesmo será criado.
  if ( -not (Test-Path "$diretorioLog\$arquivoLog")) {
    New-Item -Path "$diretorioLog\$arquivoLog" -ItemType File
    "Arquivo de log '$diretorioLog\$arquivoLog' criado com sucesso."
  }
}

function gravaLog($mensagem) {
  $time = (Get-Date -UFormat "%d/%m/%Y %H:%M:%S")

  Out-File -Filepath "$diretorioLog\$arquivoLog" -Append -InputObject "$time - $mensagem"
}

function pegaProcessosDoIISComMaiorUsoDeMemoria {
  # a variável $memoryObj retorna um objeto
  # contendo as informações dos processos que
  # estão com maior utilização de memória, no
  # total retorna 3 processos.
  $memoryObj = (
    # Consulta os objetos e faz um filtro pelo nome 'w3wp.exe'
    Get-WmiObject Win32_Process -Filter "Name='w3wp.exe'" |
    # Faz um select e transforma os dados para tornar a pesquisa e comparação mais fácil.
    Select-Object @{Name="poolName"; Expression={($_.CommandLine -Split '"')[1]}},
                  ProcessId,
                  @{Name="Mem";Expression={[Math]::Round($_.PrivatePageCount / 1mb)}} |
    Sort-Object Mem -Descending |
    Select-Object -First 3
  )

  return $memoryObj
}

function recyclePorMemoria($objeto) {
  # listando os processos com maior uso de memória.
  $listaTresObjetosComMaiorUsoDeMemoria = $objeto

  foreach ($obj in $listaTresObjetosComMaiorUsoDeMemoria) {
    # armazenando o valor de uso de memória antes do Recycle.
    $memoryUsageBefore = $obj.Mem

    # definindo o nome do POOL
    $poolName = $obj.poolName

    # definindo o Objeto do POOL
    $poolNameObj = (Get-Wmiobject -Namespace root\WebAdministration -Class ApplicationPool -Filter "Name = '$poolName'")

    # --- ATENÇÃO !!! --- #
    # Descomente a linha abaixo para para realizar o Recycle do POOL.
    $poolNameObj.Recycle()
    # -------------------------------------------------------------- #

    # armazenando o valor de uso de memória após o Recycle.
    $memoryUsageAfterObj = pegaMemoriaAposRecycle($poolName)
    $memoryUsageAfter = $memoryUsageAfterObj.Mem

    # converter Strings em double
    $memoryUsageBefore = $memoryUsageBefore -as [double]
    $memoryUsageAfter = $memoryUsageAfter -as [double]

    gravaLog("Pool name: $poolName - Memória Antes do Recycle: ${memoryUsageBefore}MB - Memória após o Recycle: ${memoryUsageAfter}MB")
  }
}

function pegaMemoriaAposRecycle($poolname) {
  Start-Sleep -Seconds $tempoDeEspera

  $poolObjeto = (
      # Consulta os objetos e faz um filtro pelo nome 'w3wp.exe'
      Get-WmiObject Win32_Process -Filter "Name='w3wp.exe'" |
      # Faz um select e transforma os dados para tornar a pesquisa e comparação mais fácil.
      Select-Object @{Name="poolName"; Expression={($_.CommandLine -Split '"')[1]}},
                    @{Name="Mem";Expression={[Math]::Round($_.PrivatePageCount / 1mb)}} |
      # pega apenas as informações de um POOL específico.
      Where-Object {$_.poolName -eq $poolname}
  )
  return $poolObjeto
}

# -- Para CPU

function pegaProcessosdoIISComMaiorUsoDeCpu {
  # Pega todos os pools ativos e os IDs dos processos IIS
  $pools = (
  # Consulta os objetos e faz um filtro pelo nome 'w3wp.exe'
  Get-WmiObject -Class Win32_Process -Filter "name='w3wp.exe'" |
  # Seleciona apenas as informações de Pool e ID.
  Select-Object @{Name="AppPool"; Expression={($_.CommandLine -Split '"')[1]}},
                ProcessId
  )

  $poolUsage = foreach ($pool in $pools){
      # pega o path do processo IIS (w3wp.exe) e transforma o mesmo para o
      # path onde está localizado as informações referentes
      # a uso de CPU (% Processor Time) para poder realizar o calculo e verificar
      # a porcentagem de utilização de CPU daquele pool.
      # retorna um Objeto contendo as informações abaixo:
      #   AppPool - Nome do Pool
      #   PID - ID do processo
      #   CPU - Valor de % de uso da CPU

      $processID = $pool.ProcessId
      $processPath = ((Get-Counter "\Process(w3wp*)\ID Process" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty CounterSamples | Where-Object {$_.RawValue -eq $processID}).Path).Replace("\id process", "\% Processor Time")
      $cpu = ([Math]::Round(((Get-Counter $processPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty CounterSamples).CookedValue / $cpuCores)))

      [PSCustomObject]@{
          AppPool = $pool.AppPool
          PID = $processID
          CPU = $cpu
      }
  }

  # Retorna um objeto com os 3 processos com maior uso de CPU.
  return ($poolUsage | Sort-Object CPU -Descending | Select-Object -First 3)
}

function recyclePorCPU {
  $usoCPUDoPoolObj = pegaProcessosdoIISComMaiorUsoDeCpu

  foreach ($obj in $usoCPUDoPoolObj) {
    # criando uma variável com o número do PID
    $processID = $obj.PID

    # armazenando o valor de uso de CPU antes do Recycle.
    $cpuUsageBefore = $obj.CPU

    if ($cpuUsageBefore -gt 9) {
      # pegando um objeto contendo a informação do nome do POOL.
      $pool = (
        # Consulta os objetos e faz um filtro pelo nome 'w3wp.exe'
        Get-WmiObject -Class Win32_Process -Filter "name='w3wp.exe'" |
        # Seleciona apenas as informações de Pool e ID.
        Select-Object @{Name="AppPool"; Expression={($_.CommandLine -Split '"')[1]}},
                      ProcessId |
        Where-Object {$_.ProcessId -eq $processID}
      )

      # definindo o nome do POOL
      $poolName = $pool.AppPool

      # definindo o Objeto do POOL
      $poolNameObj = (Get-Wmiobject -Namespace root\WebAdministration -Class ApplicationPool -Filter "Name = '$poolName'")

      # --- ATENÇÃO !!! --- #
      # Descomente a linha abaixo para para realizar o Recycle do POOL.
      $poolNameObj.Recycle()
      # -------------------------------------------------------------- #

      # armazenando o valor de uso de memória após o Recycle.
      $cpuUsageAfterObj = pegaCPUAposRecycle($poolName)
      $cpuUsageAfter = $cpuUsageAfterObj.CPU

      gravaLog("Pool name: $poolName - CPU Antes do Recycle: ${cpuUsageBefore}% - CPU após o Recycle: ${cpuUsageAfter}%")
      }
    }
}

function pegaCPUAposRecycle($poolName) {
  Start-Sleep -Seconds $tempoDeEspera

  $pool = (
  # Consulta os objetos e faz um filtro pelo nome 'w3wp.exe'
  Get-WmiObject -Class Win32_Process -Filter "name='w3wp.exe'" |
  # Seleciona apenas as informações de Pool e ID.
  Select-Object @{Name="AppPool"; Expression={($_.CommandLine -Split '"')[1]}},
                ProcessId |
  Where-Object {$_.AppPool -eq $poolName}
  )

  $processID = $pool.ProcessId
  $processPath = ((Get-Counter "\Process(w3wp*)\ID Process" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty CounterSamples | Where-Object {$_.RawValue -eq $processID}).Path).Replace("\id process", "\% Processor Time")
  $cpu = ([Math]::Round(((Get-Counter $processPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty CounterSamples).CookedValue / $cpuCores)))

  [PSCustomObject]@{
    AppPool = $poolName
    PID = $processID
    CPU = $cpu
  }
}

function validaRecycle($recursoAntes, $recursoDepois) {}

function main {
  # checando arquivos de log
  verificaArquivosDeLog

  # gravando o inicio do script
  gravaLog(">> Inicio do Script.")

  if ($componente -eq "MEM") {
    gravaLog("Intervenção devido a Alto consumo de memória.")
    recyclePorMemoria(pegaProcessosDoIISComMaiorUsoDeMemoria)
  } elseif ($componente -eq "CPU") {
    gravaLog("Intervenção devido a Alto consumo de CPU.")
    recyclePorCPU
  }

  gravaLog("/Fim do Script. <<")
  Out-File -Filepath "$diretorioLog\$arquivoLog" -Append -InputObject "# ------------------------------------------ #`n`n"
}
# --------------------------------------------------------------- #

# --- EXECUÇÃO -------------------------------------------------- #
main
# --------------------------------------------------------------- #
