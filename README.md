## 在Kubernetes上部署Hadoop和Spark

[TOC]

### 目标

* 搭建Kubernetes集群
* 在Kubernetes集群上部署Hadoop，包括HDFS和Yarn
* 基于Kubernetes部署的Hadoop，在Kubernetes上部署spark on yarn

### 部署Kubernetes集群

部署采用了官方给出的使用`kubeadm`搭建集群的方法。具体可以参考<a href="https://kubernetes.io/docs/setup/independent/install-kubeadm/">使用`kubeadm`来快速搭建集群</a>。以Ubuntu为例，其大体步骤如下：

1. 在集群中的所有节点上安装`Docker`，命令如下：

  ```
  sudo apt-get update
  sudo apt-get install -y docker.io
  ```
  若希望安装指定版本的Docker，可以参考<a href="https://docs.docker.com/install/linux/docker-ce/ubuntu/">安装Docker CE</a>

2. 在集群中的所有节点上安装`kubeadm`、`kubelet`、`kubectl`

  Kubeadm是管理Kubernetes集群的一个工具，Kubelet是Kubernetes集群中每个节点的管理者（类似于Yarn中的NodeManager角色），kubectl是Kubernetes的客户端工具，可以用来和集群进行交互。安装这三个组件步骤为：

  * 为了保证kubelet正常运行，需要关闭系统的swap功能：

    ```
    sudo swapoff --all
    ```

  * 安装apt-transport-https、curl组件

    ```
    sudo apt-get update && apt-get install -y apt-transport-https curl
    ```
  * 向apt-get 中添加package源

    ```
    sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    sudo cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
    deb http://apt.kubernetes.io/ kubernetes-xenial main
    EOF
    ```
  * 使用apt-get 安装上述三个组件

    ```
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    ```
  > **需要注意的是：**需要在集群中的每个节点均执行步骤2；且要求节点的网络能够访问cloud.google.com

3. 创建Kubernetes的Master节点

  选择集群中的一个节点作为Kubernetes的Master节点，然后可以通过Kubeadm来对初始化Master节点。在初始化Master节点之前，首先需要选择Kubernetes的DNS插件，不同的DNS插件在安装时会有不同的要求，在此示例中我们选用了Weave Net作为Kubernetes集群的DNS插件，详情可以参考<a href="https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#ui-id-7">DNS插件</a>。

  * 在Master节点上执行如下命令初始化集群。

    ```
    sudo kubeadm init
    ```

    > 有些DNS插件要求在执行上述命令时需要指定 `--pod-network-cidr`参数

  * 初始化命令执行完毕后，在输出的最后一行可以看到一个`kubeadm join`开头的命令，需要将此命令**记录下来**以便后续步骤使用。

  * 配置kubectl的配置文件，执行如下命令

    ```
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

  * 安装Kubernetes的DNS插件，该示例选用了`Weave Net`，执行如下命令：

    ```
    sudo sysctl net.bridge.bridge-nf-call-iptables=1
    export kubever=$(kubectl version | base64 | tr -d '\n')
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
    ```
    其实DNS插件也是部署在Kubernetes上的服务，所以可以通过`kubectl get pods --all-namespaces`命令查看kube-dns以及weave-net的所有pod的状态是否为`running`，如果是，则说明安装成功；如果为`container creating`，则有可能各个节点正在下载对应的image，可以稍等之后再运行上述命令验证是否安装成功。

  * (OPTION):该步骤不是必选项，默认情况下，Kubernetes的master节点不会去部署用户的Pod；如果希望master节点和其他slave节点一样可以部署用户的pod，则执行以下命令：

    ```
    kubectl taint nodes --all node-role.kubernetes.io/master-
    ```

4. 为集群中加入其它slave节点。在每个slave节点上***使用root用户***执行步骤3中记录的`kubeadm join`命令，命令的基本结构如下：

  ```
  kubeadm join --token <token> <master-ip>:<master-port> --discovery-token-ca-cert-hash sha256:<hash>
  ```

  如果没有记录上述命令，或者记录的token过期后，需要向集群中加入新的节点，可以在master节点执行如下命令生成新的`kubeadm join`命令。

  ```
  sudo kubeadm token create --print-join-command
  ```

  节点加入后，可以在master节点执行`kubectl get nodes`查看所有集群中的所有节点。

5. 如果希望删除集群中的某一个节点，通过以下方法完成。

  * 在master节点执行如下命令，将某节点删除

    ```
    kubectl drain <node name> --delete-local-data --force --ignore-daemonsets
    kubectl delete node <node name>
    ```
    其中，`<node name>`为节点的名字，可以通过`kubectl get nodes`查看。

  * 在被删除节点上执行如下命令，清除该节点的状态

    ```
    sudo kubeadm reset
    ```

### 在Kubernetes上部署HDFS和Yarn

部署HDFS和Yarn主要通过helm来完成，helm是管理Kubernetes项目的工具，具体的安装和使用方法可以参考<a href="https://docs.helm.sh/using_helm/#installing-helm">安装和使用helm</a>

1. 下载hadoop on Kubernetes项目

  为了方便部署和配置，HDFS和Yarn的部署已经被封装为简单的helm项目，可以通过如下命令下载该项目。 

  ```
  git clone https://github.com/xingtanzjr/hadoop-on-kubernetes.git
  ```
  也可以到<a href="https://github.com/xingtanzjr/hadoop-on-kubernetes">该链接</a>下直接下载zip包。

2. 创建一个Kubernetes的namespace

  为了方便管理，可以创建一个新的namespace，来部署所有的hadoop及spark项目，使用如下命令创建一个名为hadoop的namespace：

  ```
  kubectl create namespace hadoop
  ```
3. 部署HDFS

  * 在部署之前，需要对Kubernetes集群中的节点通过label进行一下功能划分，用来分别部署namenode和datanode，通过如下命令标记运行namenode的节点。

    ```
    kubectl label nodes <master-node-name> hdfs-namenode-selector=hdfs-namenode-0
    kubeclt label nodes <master-node-name> hdfs-datanode-exclude=yes
    ```
    其中，`<master-node-name>`为希望运行namenode的节点的名称。通过上述标记后，namenode将只在该节点中运行，datanode将在其他节点运行。


  * 首先部署HDFS的namenode，进入项目的charts目录，运行如下命令

    ```
    helm install -n hdfs-namenode hdfs-namenode-k8s --namespace hadoop
    ```

  * 然后部署HDFS的datanode，执行如下命令

    ```
    helm install -n hdfs-datanode hdfs-datanode-k8s --namespace hadoop
    ```

  部署完成后，可以通过网页访问`30070`端口查看HDFS的运行情况。其地址为

  ```
  http://<master-node-ip>:30070/
  ```
  其中，<master-node-ip>为运行namenode节点的IP地址。

  4. 部署Yarn

  * 首先部署Yarn的ResourceManager，进入项目的charts目录，运行如下命令：

    ```
    helm install -n yarn-rm yarn-rm --namespace hadoop
    ```
  * 然后部署Yarn的NodeManager，执行如下命令：

    ```
    helm install -n yarn-nm yarn-nm --namespace hadoop
    ```

  部署完成后，可以通过网页访问`30088`端口查看Yarn集群的运行状况，其地址为
  ​	
  ```
  http://<master-node-ip>:30088/
  ```

### 部署Spark

Yarn集群部署好之后，我们需要一个提交Spark任务的入口。当前通过在Kubernetes集群中运行了一个带有Spark的Pod来完成该功能。
​	
* 进入到项目的charts文件夹，运行如下命令启动带有Spark的Pod

  ```
  helm install -n spark spark --namespace hadoop
  ```
  启动成功后，可以通过`kubectl get pods -n hadoop`查看其运行状态，并得到该Pod的具体名称。

* 提交Spark任务

  默认情况下，spark的pod名称为spark-base-0,可以进入到该Pod来提交Spark的任务。通过如下命令进入到该Pod

  ```
  kubectl exec -ti spark-base-0 -n hadoop -- /bin/bash
  ```

  进入Pod后，默认会在Spark项目的目录下，可以通过如下命令来提交Spark on yarn的示例Job

  ```
  ./bin/spark-submit --class org.apache.spark.examples.SparkPi \
      --master yarn \
      --deploy-mode cluster \
      --driver-memory 2g \
      --executor-memory 1g \
      --executor-cores 1 \
      examples/jars/spark-examples*.jar \
      10
  ```
  任务提交后，可以通过Yarn的管理界面查看任务的状态，地址如下

  ```
  http://<master-node-ip>:30088/
  ```

  也可以通过如下命令进入Spark-shell的命令行

  ```
  ./bin/spark-shell --master yarn --deploy-mode client
  ```

### 其他问题

#### 向HDFS中上传文件

如果需要向HDFS中上传文件或者操作HDFS中的数据，则需要获得HDFS集群的地址，在该部署方法中，HDFS的地址为

```
hdfs://<master-node-ip>:8020
```
其中，`<master-node-ip>`为运行namenode的节点的IP地址。

可以通过`hadoop fs`命令来操作HDFS集群，需要注意的是，执行该命令的节点必须可以访问HDFS集群中的所有节点。`hadoop fs`是hadoop中的一个工具，需要下载hadoop后才可使用，其具体的使用方法可以参见<a href="https://hadoop.apache.org/docs/r2.7.5/hadoop-project-dist/hadoop-common/FileSystemShell.html">hadoop fs使用方法</a>
> 为了方便向HDFS中上传文件，后续可以考虑开发上传文件的脚本工具。

#### 将磁盘加入到为HDFS集群中

如果需要通过添加磁盘给HDFS扩容的话，可以参考如下步骤。

1. 将新磁盘安装在系统中

  在Linux系统环境下，安装新的磁盘后需要对其执行分区、格式化、挂载三个步骤，具体如下

  * 使用fdisk分区，具体命令如下

    ```
    # 获得新加磁盘的名称，例如名称为/dev/sdc
    fdisk -l 

    # 为新加的磁盘分区
    fdisk /dev/sdc

    # 进入到fdisk的界面后，输入n新建分区，然后可以一直使用默认配置，将磁盘划分为一个分区

    # 分区命令结束后，输入命令w保存配置，并退出fdisk

    # 格式化新分区
    mkfs -t ext4 /dev/sdc1

    # 新建一个空目录，例如为/datac,将新的分区挂在到该目录下
    mount /dev/sdc1 /datac 
    ```

  至此，一个新的磁盘就安装到了系统中，并挂载到了/datac目录下，下面，我们可以将该目录添加到HDFS的集群中，从而将HDFS的数据存入到该目录下。

2. 添加新目录到HDFS的datanode中

  * 首先通过如下命令停止datanode

    ```
    helm del --purge hdfs-datanode
    ```

  * 进入到项目的charts/hdfs-datanode-k8s/目录下，修改values.yaml文件，为属性`dataNodeHostPath:`添加一个新的目录。例如，添加前该属性的配置为:

    ```
    dataNodeHostPath:
    		- /datab/hdfs-data
    ```
    如果希望将/datac作为一个新的目录，则修改后的配置为:

    ```
    dataNodeHostPath:
    		- /datab/hdfs-data
    		- /datac/hdfs-data
    ```

  * 重新启动datanode

    ```
    helm install -n hdfs-datanode hdfs-datanode-k8s --namespace hadoop
    ```