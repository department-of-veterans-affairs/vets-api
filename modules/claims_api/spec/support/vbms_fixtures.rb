# frozen_string_literal: true

module ClaimsApi
  module Fixtures
    def get_fixture(filename)
      File.new(File.join(File.expand_path('../fixtures', __dir__), filename))
    end
  end
end

