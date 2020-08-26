# frozen_string_literal: true

require 'webmock/rspec'
require 'statsd-instrument'
require 'statsd/instrument/matchers'

module CovidResearchSpecHelper
  def read_fixture(file_name)
    path = File.expand_path('fixtures/files', __dir__)

    File.read(File.join(path, file_name))
  end
end
