# frozen_string_literal: true

module SignIn
  class ClientConfig < ApplicationRecord
    attribute :access_token_duration, :interval
    attribute :refresh_token_duration, :interval

    has_many :config_certificates, as: :config, dependent: :destroy, inverse_of: :config
    has_many :certs, through: :config_certificates,
                     class_name: 'SignIn::Certificate',
                     inverse_of: :client_configs,
                     index_errors: true

    accepts_nested_attributes_for :certs,
                                  allow_destroy: true,
                                  reject_if: ->(attrs) { attrs['pem'].blank? && attrs['id'].blank? }

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
    validates :shared_sessions, inclusion: [true, false]
    validates :enforced_terms, inclusion: { in: Constants::Auth::ENFORCED_TERMS, allow_nil: true }
    validates :terms_of_use_url, presence: true, if: :enforced_terms
    validates :client_id, presence: true, uniqueness: true
    validates :logout_redirect_uri, presence: true, if: :cookie_auth?
    validates :access_token_attributes, inclusion: { in: Constants::AccessToken::USER_ATTRIBUTES }
    validates :service_levels, presence: true, inclusion: { in: Constants::Auth::ACR_VALUES, allow_nil: false }
    validates :credential_service_providers, presence: true,
                                             inclusion: { in: Constants::Auth::CSP_TYPES, allow_nil: false }
    validates :json_api_compatibility, inclusion: [true, false]

    def self.valid_client_id?(client_id:)
      find_by(client_id:).present?
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

    def valid_credential_service_provider?(type)
      credential_service_providers.include?(type)
    end

    def valid_service_level?(acr)
      service_levels.include?(acr)
    end

    def api_sso_enabled?
      api_auth? && shared_sessions
    end

    def web_sso_enabled?
      cookie_auth? && shared_sessions
    end

    def certs_attributes=(certs_attributes)
      certs_attributes.each do |cert_attributes|
        id = cert_attributes[:id].to_s
        pem = cert_attributes[:pem].to_s
        destroy = ActiveModel::Type::Boolean.new.cast(cert_attributes[:_destroy])

        if destroy && id.present?
          cert = certs.find(id)
          certs.destroy(cert)
        else
          cert = SignIn::Certificate.find_or_initialize_by(pem:)
          certs << cert unless certs.include?(cert)
        end
      end
    end

    def as_json(options = {})
      super(options).tap do |hash|
        hash['certs'] = certs.map(&:as_json)
      end
    end

    private

    def appropriate_mock_environment?
      %w[test localhost development].include?(Settings.vsp_environment)
    end
  end
end
