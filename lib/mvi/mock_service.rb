# frozen_string_literal: true
module MVI
  class MockService
    RESPONSES = HashWithIndifferentAccess.new(
      YAML.load_file("#{Rails.root}config/mvi_schema/mock_mvi_responses.yml")
    )

    def self.method_missing(method_sym, *arguments, &block)
      RESPONSES[method_sym]
    end
  end
end
