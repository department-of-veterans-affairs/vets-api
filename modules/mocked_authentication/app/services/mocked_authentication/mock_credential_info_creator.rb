# frozen_string_literal: true

module MockedAuthentication
  class MockCredentialInfoCreator < ApplicationController
    attr_reader :credential_info

    def initialize(credential_info:)
      @credential_info = credential_info
    end

    def perform
      validate_credential_info
      create_mock_credential_info
      @mock_credential_info
    end

    private

    def validate_credential_info
      raise 'Credential Info missing' unless credential_info

      parsed_credential_info = JSON.parse(credential_info)
      raise 'CSP type required' if parsed_credential_info['type'].blank?
      raise 'Invalid CSP Type' unless SignIn::Constants::Auth::CSP_TYPES.include?(parsed_credential_info['type'])

      @parsed_credential_info = parsed_credential_info
    end

    def create_mock_credential_info
      @mock_credential_info = MockCredentialInfo.new(credential_info_code: SecureRandom.hex,
                                                     credential_info: @parsed_credential_info)
      @mock_credential_info.save!
    end
  end
end
