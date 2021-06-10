# frozen_string_literal: true

require 'tempfile'

module VBADocuments
  module Fixtures
    def get_fixture(filename)
      File.new(File.join(File.expand_path('../fixtures', __dir__), filename))
    end

    def get_erbed_fixture(filename)
      result = ERB.new(get_fixture(filename).read).result
      file = Tempfile.new
      file.write result
      file.rewind
      file
    end

    # returns a data structure based on a YAML.dump call
    def get_fixture_yml(filename)
      File.open(get_fixture(filename).path, 'r') { |f| YAML.safe_load(f) }
    end
  end
end
