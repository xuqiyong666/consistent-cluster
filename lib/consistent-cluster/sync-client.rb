
require "consistent-cluster/version"

require "consistent-cluster/consistent_hashing"

gem "zk", "~> 1.9.5" #gem本身不默认依赖zk,此处补充依赖

require "zk"

module ConsistentCluster

  class SyncClient

    def initialize(options)
      @zk = ZK.new(options[:zookeeper_service])
      @path = options[:zookeeper_path]

      @data = {}
      @cluster = {}

      replicas = options[:consistent_hashing_replicas] || 3
      @ring = ConsistentHashing::Ring.new([],replicas)

      @create_proc = options[:create_proc]
      @destroy_proc = options[:destroy_proc]
      @after_sync_proc = options[:after_sync_proc] 

      @to_sync,@syncing = false,false

      @zk.register(@path) do |event|
        sync_services
      end

      sync_services

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

    protected

    def sync_services
      @to_sync = true
      if !@syncing
        syncing_process
      end
    end

    def syncing_process
      @syncing = true
      while @to_sync
        @to_sync = false
        app_names = sync_children
        current_app_names = @cluster.keys

        to_update = current_app_names&app_names
        to_create = app_names - current_app_names
        to_destroy = current_app_names - app_names

        to_update.each do |app_name|
          update_service(app_name)
        end

        to_create.each do |app_name|
          create_service(app_name)
        end

        to_destroy.each do |app_name|
          destroy_service(app_name)
        end
      end
      @syncing = false
      if @after_sync_proc
        clone_data = Marshal.load(Marshal.dump(@data)) #avoid change outside
        @after_sync_proc.call(clone_data)
      end
    end

    def sync_children
      @zk.children(@path, watch: true)
    end

    def create_service(app_name)

      app_content = get_app_content(app_name)

      server = @create_proc.call(app_content)

      @data[app_name] = app_content

      @cluster[app_name] = server

      @ring.add(app_name)

      app_path = "#{@path}/#{app_name}"
      @zk.get(app_path, watch: true)
    rescue Exception => boom
      puts "sync create :#{app_name} raise #{boom.class} - #{boom.message}"
    end

    def destroy_service(app_name)
      return if app_name.to_s.empty?
      @ring.delete(app_name)

      if server = @cluster[app_name]
        @data.delete(app_name)
        @cluster.delete(app_name)
        if @destroy_proc
          @destroy_proc.call(server)
        end
      end

    rescue Exception => boom
      puts "sync destroy :#{app_name} raise #{boom.class} - #{boom.message}"
    end

    def update_service(app_name)
      return if app_name.to_s.empty?

      app_content = get_app_content(app_name)

      cache_info = @data[app_name]
      if cache_info != app_content
        destroy_service(app_name)
        create_service(app_name)
      end
    rescue Exception => boom
      puts "sync update :#{app_name} raise #{boom.class} - #{boom.message}"
    end

    def get_app_content(app_name)
      app_path = "#{@path}/#{app_name}"
      content = @zk.get(app_path).first
      content
    end

  end

end