# frozen_string_literal: true

def silence
  original_stdout = STDOUT.clone
  original_stderr = STDERR.clone
  $stderr.reopen File.new('/dev/null', 'w')
  $stdout.reopen File.new('/dev/null', 'w')
  yield
ensure
  $stdout.reopen original_stdout
  $stderr.reopen original_stderr
end
