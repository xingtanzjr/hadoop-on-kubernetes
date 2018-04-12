FROM xingtanzjr/hadoop-base:2.7.5
ENV SPARK_VERSION 2.3.0

ENV SPARK_HOME=/opt/spark-$SPARK_VERSION-bin-hadoop2.7
ADD spark-2.3.0-bin-hadoop2.7 /opt/spark-2.3.0-bin-hadoop2.7

RUN cp $SPARK_HOME/conf/spark-defaults.conf.template $SPARK_HOME/conf/spark-defaults.conf

WORKDIR $SPARK_HOME
ENV PATH $SPARK_HOME/bin:$PATH
ADD spark-entrypoint.sh /
ADD spark-historyserver.sh /
RUN chmod a+x /spark-entrypoint.sh
RUN chmod a+x /spark-historyserver.sh
ENTRYPOINT ["/spark-entrypoint.sh"]