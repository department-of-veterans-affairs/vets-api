class ShellCommand
  # runs shell command and prints output
  # returns boolean depending on the success of the command
  def self.run(command)
    success = false

    Open3.popen2e(command) do |_stdin, stdout_and_stderr, thread|
      while (line = stdout_and_stderr.gets)
        puts(line)
      end

      success = thread.value == 0
    end

    success
  end
end
