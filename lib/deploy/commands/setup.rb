require_relative '../command'
require_relative '../config'

module Deploy
  module Commands
    class Setup < Command
      def run
        pid = Process.spawn(
          "ls | grep ubuntu",
          chdir: Config.ansible_path,
          out: "./out.log"
        )
        puts pid
        Process.detach(pid)
      end
    end
  end
end
