$:.push File.expand_path("lib", __dir__)
require "consistent-cluster/version"

gem_files = `git ls-files -- lib/*`.split("\n")

Gem::Specification.new do |s|
  s.name         = "consistent-cluster"
  s.version      = ConsistentCluster::Version
  s.authors     = ["jeffrey6052"]
  s.email       = ["jeffrey6052@163.com"]
  s.homepage    = "https://github.com/Jeffrey6052/consistent-cluster"
  s.summary     = "一致性哈希集群"
  s.description = "用于整合服务集群接口，方便客户端调用; 调用方式包含一致性哈希逻辑,轮询逻辑; 支持绑定zookeeper,同步集群配置"

  s.files         = gem_files

  s.add_runtime_dependency "atomic", "~> 1.1"

end
