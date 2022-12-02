#!/usr/bin/env bash

# Version 1.5 Dic 2, 2022
# Set the path so cron can find jq, necessary for cron depending on your default PATH
# Se debe tener instalado el paquete jq

export PATH=$PATH:~/bin/
LOGFILE=/var/tmp/qtm-kafka.log
RESULTADO=$(mktemp)

mensaje() {

# Forma de uso:
# mensaje -m IP       "Solo el mensaje"
# mensaje -l -m IP    "El mensaje y logeando"
# mensaje -j -m IP    "El mensaje en JSON"
# mensaje -j -l -m IP "El mensaje en JSON y logueando"
# variable LOGFILE debe definirse globalmente

  [ $# -eq 0 ] && echo "Error: mensaje() necesita parametros!!!" && return 1

  local LOG=1
  local JSON=1

  while [ $# -gt 0 ] 
  do    
    case "$1" in
      "-l") LOG=0;;
      "-j") JSON=0;;
      "-m") 
        shift 
        [ "$1" == "" ] && echo "Error: Necesito el mensaje a imprimir" && return 1
        local AHORA=$(date +"%Y-%m-%d %H:%M:%S")
        local MENSAJE="$1";;
      *) 
        echo "Error: mensaje() debe tener algun parametro de estos: -m CADENA [-l|-j]" && return 1;;
    esac
    shift
  done
  

  if [ ${JSON} -eq 0 ]; then # entra x 0
    MENSAJE=$(echo -e "${AHORA} message:{\n  \"fecha\":\"${AHORA}\",\n  \"mensaje\":\"${MENSAJE}\"\n}")
  else
    MENSAJE="${AHORA} ${MENSAJE}"
  fi

  if [ ${LOG} -eq 0 ]; then
    echo "${MENSAJE}" | tee -a ${LOGFILE}
  else
    echo "${MENSAJE}"
  fi
}

[ "$1" == "" ] && echo "Error: Necesito tener algun parametro  válido: -m CADENA [-l|-j]!! ulitize $0 -h para más ayuda" && exit 1
# Obtener IP
case "$1" in
  "-m") 
    [ "$2" == "" ] && echo "Error: Necesito el IP del servidor!!" && exit 1    
    IP="$2";;
  "-l") 
    [ "$3" == "" ] && echo "Error: Necesito el IP del servidor!!" && exit 1
    IP="$3";;
  "-j") 
    [ "$4" == "" ] && echo "Error: Necesito el IP del servidor!!" && exit 1
    IP="$4";;
  "-h") 
    echo "Uso: $0 [-m|-l|-j] IP"
    echo " $0 -m IP       : Solo el mensaje"
    echo " $0 -l -m IP    : El mensaje y logeando"
    echo " $0 -j -l -m IP : El mensaje en JSON"
    echo " $0 -h          : Ayuda"
    exit 0;;
  *) 
  echo "Error: Parámetro incorrecto. Necesito tener algun parametro  válido: -m CADENA [-l|-j]!!" 
  exit 1;;
esac

# Validar conexion
curl -s "http://${IP}:8083/connectors?expand=info&expand=status" > ${RESULTADO}
[ $? -ne 0 ] && mensaje -l -m "ERROR - No se puede listar los conectores." && rm -f ${RESULTADO} && exit 1
RESPONSE=$(grep error_code ${RESULTADO} | cut -d, -f1 | cut -d: -f2)
[ ! -z "${RESPONSE}" ] && mensaje -l -m "ERROR - ${RESPONSE} -No se puede listar los conectores." && rm -f ${RESULTADO} && exit 2

# List current connectors and status
curl -s "http://${IP}:8083/connectors?expand=info&expand=status" | \
           jq '. | to_entries[] | [ .value.info.type, .key, .value.status.connector.state,.value.status.tasks[].state,.value.info.config."connector.class"]|join(":|:")' | \
           column -s : -t| sed 's/\"//g'| sort > ${RESULTADO}
RESPONSE=$(grep "FAILED\|PAUSED" ${RESULTADO} | cut -d"|" -f2)
[ ! -z "${RESPONSE}" ] && mensaje -l -m "ERROR - Conectores con fallas: ${RESPONSE}"

# Restart any connector tasks that are FAILED
# Works for Apache Kafka >= 2.3.0 
# Restart Connector
curl -s "http://${IP}:8083/connectors?expand=status" | \
  jq -c -M 'map({name: .status.name ,conector:.status.connector} )| .[] | {name: .name, state: .conector.state}| if(.state=="PAUSED" or .state=="FAILED") then  {name: .name} | ("/connectors/"+.name+"/restart") else empty end' | \
  xargs -I{connector} curl -v -X PUT "http://${IP}:8083"\{connector\}
# Restart Tasks
curl -s "http://${IP}:8083/connectors?expand=status" | \
  jq -c -M 'map({name: .status.name } +  {tasks: .status.tasks}) | .[] | {task: ((.tasks[]) + {name: .name})}  | select(.task.state==("FAILED","PAUSED")) | {name: .task.name, task_id: .task.id|tostring} | ("/connectors/"+.name+"/tasks/"+.task_id+"/restart")' | \
  xargs -I{connector_and_task} curl -v -X POST "http://${IP}:8083"\{connector_and_task\}

rm -f ${RESULTADO}