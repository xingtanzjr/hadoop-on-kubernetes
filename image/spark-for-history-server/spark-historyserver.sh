#!/bin/sh

hadoop fs -fs "${CORE_CONF_fs_defaultFS}" -test -e "${spark_eventLog_dir}"
if [ $? -eq 0 ] ;then  
    echo 'spark history dir existed'
else  
    hadoop fs -fs "${CORE_CONF_fs_defaultFS}" -mkdir -p "${spark_eventLog_dir}"
    echo 'create dir for spark-history-sever: ${spark_eventLog_dir}'
fi  

exec ./sbin/start-history-server.sh "${SPARK_CONF_spark_eventLog_dir}"
echo "start spark history server done."
tail -f /spark-historyserver.sh