# frozen_string_literal: true

module MockedAuthentication
  class CredentialInfoCreator
    attr_reader :credential_info

    def initialize(credential_info:)
      @credential_info = credential_info
    end

    def perform
      create_mock_credential_info
      mock_credential_info.credential_info_code
    end

    private

    def create_mock_credential_info
      mock_credential_info.save!
    end

    def mock_credential_info
      @mock_credential_info ||= CredentialInfo.new(credential_info_code:,
                                                   credential_info: parsed_credential_info)
    end

    def parsed_credential_info
      @parsed_credential_info ||= JSON.parse(Base64.decode64(credential_info)).deep_symbolize_keys
    end

    def credential_info_code
      @credential_info_code ||= SecureRandom.hex
    end
  end
end
