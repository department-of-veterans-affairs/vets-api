# frozen_string_literal: true

module VBADocuments
  module Fixtures
    def get_fixture(filename)
      File.new(File.join(File.expand_path('../fixtures', __dir__), filename))
    end

    # returns a data structure based on a YAML.dump call
    def get_fixture_yml(filename)
      File.open(File.join(File.expand_path('../fixtures', __dir__), filename), 'r') { |f| YAML.safe_load(f) }
    end
  end
end
