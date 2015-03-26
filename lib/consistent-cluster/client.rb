
require "consistent-cluster/version"

require "consistent-cluster/consistent_hashing"

require "json"

module ConsistentCluster

  class Client

    def initialize(options)

      @cluster = options[:cluster]

      replicas = options[:consistent_hashing_replicas] || 3
      @ring = ConsistentHashing::Ring.new(@cluster.keys,replicas)

      @shard_num = 0
    end

    def shard(key=nil)
      cluster_sum = @cluster.length
      raise "no service available" if cluster_sum < 1
      if key
        point = @ring.point_for(key)
        server = @cluster[point.node]
      else
        @shard_num += 1
        @shard_num = @shard_num%cluster_sum
        server = @cluster.values[@shard_num]
      end
      server
    end

  end

end