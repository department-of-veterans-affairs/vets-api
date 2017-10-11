# frozen_string_literal: true
require 'mvi/models/mvi_profile'

module MVI
  class MockService
    def mocked_responses
      @responses ||= YAML.load_file('config/mvi_schema/mock_mvi_responses.yml')
    end

    def find_profile(user)
      response = if user.mhv_icn.present?
                   mocked_responses['find_candidate'].values.group_by { |h| h[:icn] }.dig(user.mhv_icn)&.first
                 else
                   mocked_responses.dig('find_candidate', user.ssn)
                 end
      if response
        profile = MVI::Models::MviProfile.new(response)
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
