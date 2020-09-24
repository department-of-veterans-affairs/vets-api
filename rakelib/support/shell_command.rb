# frozen_string_literal: true

class ShellCommand
  # runs shell command and prints output
  # returns boolean depending on the success of the command
  def self.run(command)
    success = false
    old_sync = $stdout.sync
    $stdout.sync = true

    Open3.popen2e(command) do |_stdin, stdout_and_stderr, thread|
      while (line = stdout_and_stderr.gets)
        puts(line)
      end

      success = thread.value.success?
    end

    $stdout.sync = old_sync
    success
  end
end
