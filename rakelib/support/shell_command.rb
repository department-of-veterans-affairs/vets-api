# frozen_string_literal: true

require 'open3'

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

  def self.run_quiet(command)
    success = false
    old_sync = $stdout.sync
    $stdout.sync = true

    Open3.popen3(command) do |_stdin, _stdout, stderr, wait_thr|
      error = stderr.read
      puts error unless error.empty?

      success = wait_thr.value.exitstatus.zero?
    end

    $stdout.sync = old_sync
    success
  end
end
