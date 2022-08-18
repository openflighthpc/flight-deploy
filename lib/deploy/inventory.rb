require_relative './config'

module Deploy
  class Inventory
    def self.load(name=nil)
      begin
        file = File.read(File.join(Config.ansible_inv_dir, "#{name}.inv"))
        # Split string by "any string in between two square brackets",
        # keeping the delimiter as part of the split string.
        groups = file.split(/(?=\[.*\])/).reject(&:empty?)

        inventory = {}
        groups.each do |r|
          group = r.split("\n")
          # First slice removes the square brackets from group name
          # Second slice takes every row except the first one (so,
          # all the nodes excluding the group name)
          inventory[group[0][1...-1]] = group[1..-1]
        end

        new(cluster_name: name, groups: inventory)

      # File not found? Create it.
      rescue Errno::ENOENT
        new(cluster_name: name, groups: {}).tap do |inv|
          inv.dump
        end
      end
    end

    def to_raw
      groups.map do |group, nodes|
        nodes_str = nodes.join("\n")
        "[#{group}]\n#{nodes_str}"
      end.join("\n\n")
    end

    def dump
      File.open(filepath, 'w+') { |f| f.write(to_raw) }
    end

    def filepath
      File.join(Config.ansible_inv_dir, "#{cluster_name}.inv")
    end

    attr_accessor :cluster_name, :groups

    def initialize(cluster_name:, groups:)
      @cluster_name = cluster_name
      @groups = groups
    end
  end
end
