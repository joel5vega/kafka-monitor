# Manual implementación
## Pruebas
Listar conectores
```bash curl -s "http://172.28.67.14:8083/connectors" ```
### Prueba 1
Verificar que todos los conectores esten en running
```bash curl -s "http://172.28.67.14:8083/connectors?expand=status" ```
Verificar que ningun conector esta en pausa
```bash curl -s "http://172.28.67.14:8083/connectors?expand=status"|grep -i "paused\|failed ```
Pausar el connector
```bash curl -sX PUT  http://172.28.67.14:8083/connectors/ enLinea_BCCS_HEADER/pause ```
Verificar que conector esta en pausa
```bash curl -s "http://172.28.67.14:8083/connectors?expand=status"|grep -i paused ```
Ejecutar el script de prueba
```bash ./restartTask.sh -m 172.28.67.14 ```
### Rollback
```bash curl -sX PUT  http://172.28.67.14:8083/connectors/enLinea_BCCS_HEADER/resume ```