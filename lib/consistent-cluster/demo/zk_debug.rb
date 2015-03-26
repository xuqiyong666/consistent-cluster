require 'zk'
require 'json'

$zk = ZK.new("127.0.0.1:2181")

$path = "/test"

def create(hash)
  app_name = hash[:id]

  $zk.create("#{$path}/#{app_name}",hash.to_json)
end

def set(hash)
  app_name = hash[:id]
  $zk.set("#{$path}/#{app_name}",hash.to_json)
end

def delete(app)
  $zk.delete("#{$path}/#{app}")
end

def clear
  apps = $zk.children($path)
  apps.each do |app|
    delete(app)
  end
end


app1 = {
  group: "uts",
  host: "127.0.0.1",
  port: "9091",
  id: "127.0.0.1:9091",
  protocolType: "thrift",
  serviceNames: ["com.ximalaya.service.uts.api.thrift.IUserTrackRecordServiceHandler$Iface"]
}

app2 = {
  group: "uts",
  host: "127.0.0.1",
  port: "9092",
  id: "127.0.0.1:9092",
  protocolType: "thrift",
  serviceNames: ["com.ximalaya.service.uts.api.thrift.IUserTrackRecordServiceHandler$Iface"]
}

app3 = {
  group: "uts",
  host: "127.0.0.1",
  port: "9093",
  id: "127.0.0.1:9093",
  protocolType: "thrift",
  serviceNames: ["com.ximalaya.service.uts.api.thrift.IUserTrackRecordServiceHandler$Iface"]
}

clear

create(app1)

create(app2)

create(app3)

#set(app2)



