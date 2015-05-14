
require "consistent-cluster/version"

require "consistent-cluster/consistent_hashing"

require "zk"

module ConsistentCluster

  class SyncClient

    def initialize(options)

      @data = {}
      @cluster = {}
      @node_register = {}

      replicas = options[:consistent_hashing_replicas] || 3
      @ring = ConsistentHashing::Ring.new([],replicas)

      @create_proc = options[:create_proc]
      @destroy_proc = options[:destroy_proc]
      @after_sync_proc = options[:after_sync_proc] 

      @to_sync,@syncing = false,false
      
      @path = options[:zookeeper_path]

      @zk = ZK.new(options[:zookeeper_service],reconnect: true)

      @zk.register(@path) do |event|
        sync_services
      end

      sync_services

      #on_state_change
      #on_connecting
      #on_expired_session
      @zk.on_connected do
        reconnect_callback
      end

      @shard_num = 0
    end

    def reconnect_callback
      case @zk.state
      when :connected
        sync_services
      end
    end

    def shard(key=nil)
      cluster_sum = @cluster.length
      raise "no service available at #{@path}" if cluster_sum < 1
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
        app_names = get_app_names
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

    def get_app_names
      @zk.children(@path, watch: true)
    end

    def create_service(app_name)

      app_path = "#{@path}/#{app_name}"
      @node_register[app_name] = @zk.register(app_path) do |event|
        sync_services
      end

      app_content = get_app_content(app_name)

      server = @create_proc.call(app_content)

      if server

        @cluster[app_name] = server

        @ring.add(app_name)

        @data[app_name] = app_content

      end

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

      reg = @node_register[app_name]
      if reg
        reg.unregister
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
      content = @zk.get(app_path, watch: true).first
      content
    end

  end

end