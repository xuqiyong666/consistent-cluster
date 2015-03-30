
require "consistent-cluster/sync-client"

require "thrift_client"

require "happy_profile/client/thrift" #thrift client example

require "json"

all_config = {
  consistent_hashing_replicas: 100,
  create_proc: Proc.new { |zk_content|
    app_info = JSON.parse(zk_content)
    client = ThriftClient.new(
      "servers" => "#{app_info["host"]}:#{app_info["port"]}",
      "multiplexed" => app_info["serviceNames"].length > 1,
      "protocol" => 'binary',
      "transport" => 'socket',
      "framed" => false,
      "disconnect_exception_classes" => '',
      "application_exception_classes" => '',
      "size" => 1,
      "timeout" => 12,
      "client_class" => "HappyProfile::HappyProfileThriftService::Client",
      "test_on_borrow" => true,
      "pool_timeout" => 12)
  },
  destroy_proc: Proc.new { |client|
    client.destroy
  },
  after_sync_proc: Proc.new { |info|
    puts info.keys.inspect
  },
  zookeeper_service: "127.0.0.1:2181",
  zookeeper_path: "/test"
}

profile_services = ConsistentCluster::SyncClient.new(all_config)

while true

  sleep 1

  key = rand(10000)

  2.times do
    begin
      profile_services.shard(key).ping.inspect
    rescue Exception => boom
      puts boom.message
    end
  end

end

# while true

#   sleep 1

#   begin
#     profile_services.shard.ping.inspect
#   rescue Exception => boom
#     puts boom.message
#   end

# end

