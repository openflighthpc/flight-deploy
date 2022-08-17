require_relative './config'

module Deploy
  class Inventory
    def self.load(name:)
      begin
        file = File.read(File.join(Config.ansible_inv_dir, "#{name}.inv"))
        groups = file.split(/(?=\[.*\])/).reject(&:empty?)

        inventory = groups.map do |r|
          group = r.split("\n")
          { group: group[0][1...-1], nodes: group[1..-1] }
        end

        new(name, inventory)
      rescue Errno::ENOENT
        new(name, []).tap do |inv|
          inv.dump
        end
      end
    end

    def to_raw
      groups.map do |row|
        nodes_str = row[:nodes].join("\n")
        "[#{row[:group]}]#{nodes_str}"
      end.join("\n\n")
    end

    def dump
      File.open(filepath, 'w+') { |f| to_raw }
    end

    def filepath
      File.join("var", "#{cluster_name}.yaml")
    end

    def initialize(cluster_name:, groups:)
      @cluster_name = cluster_name
      @groups: groups
    end
  end
end
