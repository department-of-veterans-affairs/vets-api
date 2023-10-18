# frozen_string_literal: true

module SignIn
  class ClientConfig < ApplicationRecord
    attribute :access_token_duration, :interval
    attribute :refresh_token_duration, :interval

    validates :anti_csrf, inclusion: [true, false]
    validates :redirect_uri, presence: true
    validates :access_token_duration,
              presence: true,
              inclusion: { in: Constants::AccessToken::VALIDITY_LENGTHS, allow_nil: false }
    validates :refresh_token_duration,
              presence: true,
              inclusion: { in: Constants::RefreshToken::VALIDITY_LENGTHS, allow_nil: false }
    validates :authentication,
              presence: true,
              inclusion: { in: Constants::Auth::AUTHENTICATION_TYPES, allow_nil: false }
    validates :enforced_terms, inclusion: { in: Constants::Auth::ENFORCED_TERMS, allow_nil: true }
    validates :terms_of_use_url, presence: true, if: :enforced_terms
    validates :client_id, presence: true, uniqueness: true
    validates :logout_redirect_uri, presence: true, if: :cookie_auth?
    validates :access_token_attributes, inclusion: { in: Constants::AccessToken::USER_ATTRIBUTES }

    def self.valid_client_id?(client_id:)
      find_by(client_id:).present?
    end

    def client_assertion_public_keys
      @client_assertion_public_keys ||= certificates.compact.map do |certificate|
        OpenSSL::X509::Certificate.new(certificate).public_key
      end
    end

    def cookie_auth?
      authentication == Constants::Auth::COOKIE
    end

    def api_auth?
      authentication == Constants::Auth::API
    end

    def mock_auth?
      authentication == Constants::Auth::MOCK && appropriate_mock_environment?
    end

    def va_terms_enforced?
      enforced_terms == Constants::Auth::VA_TERMS
    end

    private

    def appropriate_mock_environment?
      %w[test localhost development].include?(Settings.vsp_environment)
    end
  end
end
