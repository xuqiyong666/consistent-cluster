
#consistent-cluster

用于整合服务集群接口，方便客户端调用

调用方式包含一致性哈希逻辑,轮询逻辑

支持绑定zookeeper,同步集群配置

## 安装

```sh
$ gem install consistent-cluster
```

## 使用说明

###一、 使用zookeeper自动同步集群配置

``` ruby
# -*- coding: utf-8 -*-

require "consistent-cluster/sync-client"

all_config = {

  #必填 zookeeper的ip+端口信息
  zookeeper_service: "127.0.0.1:2181",

  #必填 zookeeper指定目录
  zookeeper_path: "/test",

  #必填 单个服务对象的创建Proc，node_content为zookeeper节点中存放的值
  create_proc: Proc.new { |node_content|     
    app_info = JSON.parse(node_content) #比如zookeeper节点中存放的是json字符串
    ThriftClient.new("servers" => "#{app_info["host"]}:#{app_info["port"]}",
                    "multiplexed" => app_info["serviceNames"].length > 1,
                    "protocol" => 'binary',
                    "transport" => 'socket') 比如生成thrift客户端
  },

  #选填 可以补充一些删除服务器时的操作,比如客户端需要手动断开连接操作，client为上面create_proc的返回值
  destroy_proc: Proc.new { |client|
    client.destroy
  }, 

  #选填 同步zookeeper信息之后，会调用这个proc，info为同步到的zookeeper信息，可以打印出info方便debug。一般不需要配置。
  after_sync_proc: Proc.new { |info|
    puts info.inspect
  }, 

  #选填 一致性哈希环中，每个服务的虚拟节点数量，默认值: 3
  consistent_hashing_replicas: 100
}

#zookeeper指定目录结构说明: 目录中的每一个节点代表一个独立的服务器,节点名称作为服务器名称,节点的内容作为服务器的配置信息


#创建实例
ProfileServices = ConsistentCluster::SyncClient.new(all_config)

#使用shard方法调度集群
#当传key值时，将会使用一致性哈希调度方式，这种方式下相同的key将会访问同一台服务器
key = "string,integer,boolen,object or anything"
ProfileServices.shard(key).get_user_basic_info(1000018)

#当不传key值时，将会使用轮询调度方式
ProfileServices.shard.get_user_basic_info(1003231)

```


###二、直接配置（自定义配置，不依赖zookeeper服务）
``` ruby
# -*- coding: utf-8 -*-

require "consistent-cluster/client"

#定义服务器集群hash
cluster = {}
["127.0.0.1:9091","127.0.0.1:9092","127.0.0.1:9093"].each do |iport|
  app_name = iport
  cluster[app_name] = ThriftClient.new("servers" => iport,
                  "multiplexed" => false,
                  "protocol" => 'binary',
                  "transport" => 'socket')
end

all_config = {

  consistent_hashing_replicas: 100, #选填 一致性哈希环中，每个服务的虚拟节点数量，默认值: 3

  cluster: cluster                  #必填 服务器集群hash
}

#创建实例
ProfileServices = ConsistentCluster::Client.new(all_config)

#使用shard方法调度集群
#当传key值时，将会使用一致性哈希调度方式，这种方式下相同的key将会访问同一台服务器
key = "string,integer,boolen,object or anything"
ProfileServices.shard(key).get_user_basic_info(1000018)

#当不传key值时，将会使用轮询调度方式
ProfileServices.shard.get_user_basic_info(1003231)

```



yeah.happy coding:)

