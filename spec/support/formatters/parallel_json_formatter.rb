# frozen_string_literal: true

require 'rspec/core/formatters/json_formatter'

class ParallelJsonFormatter < RSpec::Core::Formatters::JsonFormatter
  RSpec::Core::Formatters.register self, :message, :dump_summary, :dump_profile, :stop, :seed, :close

  def initialize(_output)
    test_env_number = ENV['TEST_ENV_NUMBER'] || ''
    file_path = "tmp/rspec#{test_env_number}.json"
    FileUtils.mkdir_p('tmp')
    output = File.open(file_path, 'w')
    super(output)
    @output_path = file_path
  end

  def close(_notification)
    super
    @output.close if @output.respond_to?(:close)
  end
end
