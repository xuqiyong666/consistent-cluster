
require "consistent-cluster/client"

require "thrift_client"

require "happy_profile/client/thrift" #thrift client example

cluster = {}

["127.0.0.1:9091","127.0.0.1:9092","127.0.0.1:9093"].each do |iport|
  cluster[iport] = ThriftClient.new("servers" => iport,
                  "multiplexed" => false,
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
end

all_config = {
  consistent_hashing_replicas: 100,
  cluster: cluster
}

profile_services = ConsistentCluster::Client.new(all_config)

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

