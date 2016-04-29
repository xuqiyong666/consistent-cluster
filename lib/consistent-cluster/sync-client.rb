
require "consistent-cluster/version"

require "consistent-cluster/consistent_hashing"

require "zk"

module ConsistentCluster

  class SyncClient

    def initialize(options)

      @syncingMutex = Mutex.new

      @data = {}
      @cluster = {}
      @node_register = {}

      replicas = options[:consistent_hashing_replicas] || 3
      @ring = ConsistentHashing::Ring.new([],replicas)

      @create_proc = options[:create_proc]
      @destroy_proc = options[:destroy_proc]
      @after_sync_proc = options[:after_sync_proc]
      @log_proc = options[:log_proc]

      @logger = if options[:log_file]
        Logger.new(options[:log_file])
      elsif STDERR || STDOUT
        Logger.new(STDERR || STDOUT)
      else
        Logger.new(options[:nil])
      end

      @last_sync_at = 0

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

      check_timer = options[:check_timer]
      check_timer ||= 60 #default 1 minutes gap

      start_check_timer_thread(check_timer)

      @shard_num = 0
    end

    def start_check_timer_thread(check_timer)
      return if check_timer <= 0
      Thread.new {
        while true
          sleep check_timer
          if !@syncingMutex.locked? && local_version != remote_version
            sync_services
          end
        end
      }
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

    def invoke_sync
      sync_services
    end

    def local_version
      @data
    end

    def remote_version
      app_names = get_app_names(watch: false)

      data = {}
      app_names.each do |app_name|
        app_content = get_app_content(app_name, watch: false)
        data[app_name] = app_content
      end
      data
    end

    def zookeeper_path
      @path
    end

    def last_sync_at
      @last_sync_at
    end

    protected

    def reconnect_callback
      case @zk.state
      when :connected
        sync_services
      end
    end

    def sync_services
      @syncingMutex.synchronize do
        syncing_process
      end
    end

    def syncing_process
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

      @last_sync_at = Time.now.to_i

      if @after_sync_proc || @log_proc
        clone_data = Marshal.load(Marshal.dump(@data)) #avoid change outside

        if @after_sync_proc
          @after_sync_proc.call(clone_data)
        end

        if @log_proc
          debugInfo = @log_proc.call(@data).to_s
          if debugInfo != ""
            @logger.info debugInfo
          end
        end
      end
    end

    def get_app_names(options = {watch: true})
      @zk.children(@path, watch: options[:watch])
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
      @logger.error "syncClientError when create :#{app_name} raise #{boom.class} - #{boom.message}"
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
      @logger.error "syncClientError when destroy :#{app_name} raise #{boom.class} - #{boom.message}"
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
      @logger.error "syncClientError when update :#{app_name} raise #{boom.class} - #{boom.message}"
    end

    def get_app_content(app_name, options={watch: true})
      app_path = "#{@path}/#{app_name}"
      content = @zk.get(app_path, watch: options[:watch]).first
      content
    end

  end

end
