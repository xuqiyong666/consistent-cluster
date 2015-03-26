
require "consistent-cluster"

profile_servers_map = {
  x1:  {ip: "192.168.1.136", port: "8081"},
  x2:  {ip: "192.168.1.136", port: "8081"},
  x3:  {ip: "192.168.1.136", port: "8081"},
  x4:  {ip: "192.168.1.136", port: "8081"}
}

nodes = profile_servers_map.keys

ch_ring = ConsistentCluster::ConsistentHashing::Ring.new(nodes,10)


(1..100).each do |key|
  p ch_ring.point_for(key)
end