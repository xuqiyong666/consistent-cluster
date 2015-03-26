$:.push File.expand_path("lib", __dir__)
require "consistent-cluster/version"

gem_files = `git ls-files -- lib/*`.split("\n")

Gem::Specification.new do |s|
  s.name         = "consistent-cluster"
  s.version      = ConsistentCluster::Version
  s.authors     = ["jeffrey6052"]
  s.email       = ["jeffrey6052@163.com"]
  s.homepage    = ""
  s.summary     = "用于打包集群服务接口，方便客户端调用"
  s.description = "\n红黑树,一致性Hash算法，Hash环\n支持zookeeper同步(依赖gem： zk)"

  s.files         = gem_files

  s.add_runtime_dependency "atomic", "~> 1.1.99"

end
