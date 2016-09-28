# frozen_string_literal: true
module MVI
  class MockService
    def self.mocked_responses
      @responses ||= YAML.load_file("#{Rails.root}/config/mvi_schema/mock_mvi_responses.yml")
    end

    def self.find_candidate
      mocked_responses['find_candidate']
    end
  end
end
