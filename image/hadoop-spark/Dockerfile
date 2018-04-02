FROM xingtanzjr/hadoop-base:2.7.5
ENV SPARK_VERSION 2.3.0

ENV SPARK_HOME=/opt/spark-$SPARK_VERSION-bin-hadoop2.7
ADD spark-$SPARK_VERSION-bin-hadoop2.7 /opt/spark-$SPARK_VERSION-bin-hadoop2.7

WORKDIR $SPARK_HOME
ENV PATH $SPARK_HOME/bin:$PATH
ADD spark-entrypoint.sh /
ADD spark-historyserver.sh /
ADD spark-master.sh /
ADD spark-slave.sh /
RUN chmod a+x \
    /spark-entrypoint.sh \
    /spark-historyserver.sh \
    /spark-master.sh \
    /spark-slave.sh
ENTRYPOINT ["/entrypoint.sh"]