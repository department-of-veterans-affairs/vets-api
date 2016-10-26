# frozen_string_literal: true
module MVI
  class MockService
    def self.mocked_responses
      @responses ||= YAML.load_file('config/mvi_schema/mock_mvi_responses.yml')
    end

    def self.find_candidate(message)
      response = mocked_responses.dig('find_candidate', message.ssn)
      if response
        ActiveSupport::HashWithIndifferentAccess.new(response)
      else
        MVI::Service.find_candidate(message)
      end
    rescue MVI::ServiceError, HTTPI::SSLError => e
      Rails.logger.error "No user found by key #{message.ssn} in mock_mvi_responses.yml, "\
      "the remote service was invoked but received an error: #{e.message}"
      raise e
    end
  end
end
