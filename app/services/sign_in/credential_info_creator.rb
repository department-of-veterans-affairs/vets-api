# frozen_string_literal: true

module SignIn
  class CredentialInfoCreator
    attr_reader :csp_user_attributes, :csp_token_response

    def initialize(csp_user_attributes:, csp_token_response:)
      @csp_user_attributes = csp_user_attributes
      @csp_token_response = csp_token_response
    end

    def perform
      return unless authenticated_csp_is_logingov?

      create_credential_info
    end

    private

    def create_credential_info
      credential_info = CredentialInfo.new(csp_uuid: csp_uuid, id_token: id_token, credential_type: credential_type)
      credential_info.save!
      credential_info.expire(expires_in)
    rescue Common::Exceptions::ValidationErrors, Redis::CommandError
      raise Errors::InvalidCredentialInfoError, 'Cannot save information for malformed credential'
    end

    def authenticated_csp_is_logingov?
      credential_type == 'logingov'
    end

    def credential_type
      @credential_type ||= csp_user_attributes[:sign_in][:service_name]
    end

    def csp_uuid
      @csp_uuid ||= csp_user_attributes[:uuid]
    end

    def id_token
      @id_token ||= csp_token_response[:id_token]
    end

    def expires_in
      @expires_in ||= csp_token_response[:expires_in]
    end
  end
end
