# frozen_string_literal: true
module MVI
  class MockService
    def mocked_responses
      @responses ||= YAML.load_file('config/mvi_schema/mock_mvi_responses.yml')
    end

    def find_profile(user)
      response = mocked_responses.dig('find_candidate', user.ssn)
      if response
        profile = MviProfile.new(response)
        MVI::Responses::FindProfileResponse.new(
          status: MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
          profile: profile
        )
      else
        MVI::Service.new.find_profile(user)
      end
    rescue Common::Client::Errors::HTTPError => e
      Rails.logger.error "No user found by key #{user.ssn} in mock_mvi_responses.yml, "\
      "the remote service was invoked but received an error: #{e.message}"
      raise e
    end
  end
end
