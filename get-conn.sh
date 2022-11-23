#!/usr/bin/env bash
cat list-connectors.json |\
jq -c -M 'map({name: .status.name } +  {tasks: .status.tasks})| .[] | {task: ((.tasks[]) + {name: .name})}  | select(.task.state==("PAUSED", "FAILED")) | {name: .task.name,     task_id: .task.id|tostring} | ("/connectors/"+ .name +  "/tasks/" + .task_id + "/restart")'
cat list-connectors.json |\
jq -c -M 'map({name: .status.name ,conector:.status.connector} )| .[] | {name: .name, state: .conector.state}| if(.state=="PAUSED" or .state=="FAILED") then  {name: .name} | ("/connectors/"+ .name + "/restart") else empty end'

curl -s "http://172.28.67.14:8083/connectors?expand=status"