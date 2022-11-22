#!/usr/bin/env bash
cat list-connectors.json |\
jq -c -M 'map({name: .status.name } +  {tasks: .status.tasks})| .[] | {task: ((.tasks[]) + {name: .name})}  | select(.task.state=="RUNNING") | {name: .task.name,     task_id: .task.id|tostring} | ("/connectors/"+ .name +  "/tasks/" + .task_id + "/restart")'