# frozen_string_literal: true
module MVI
  class MockService
    def self.mocked_responses
      @responses ||= YAML.load_file('config/mvi_schema/mock_mvi_responses.yml')
    end

    def self.find_candidate(_message)
      mocked_responses['find_candidate'].with_indifferent_access
    end
  end
end
