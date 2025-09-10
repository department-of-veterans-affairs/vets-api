# frozen_string_literal: true

module SignIn
  class ClientConfig < ApplicationRecord
    attribute :access_token_duration, :interval
    attribute :refresh_token_duration, :interval

    has_many :config_certificates, as: :config, dependent: :destroy, inverse_of: :config, index_errors: true
    has_many :certs, through: :config_certificates, source: :cert, index_errors: true

    accepts_nested_attributes_for :config_certificates, allow_destroy: true

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

    def certs_attributes=(attributes)
      normalized_attributes = attributes.is_a?(Hash) ? attributes.values : Array(attributes)
      self.config_certificates_attributes = normalized_attributes.map do |cert_attrs|
        cert_attrs = cert_attrs.to_h.symbolize_keys
        should_destroy = ActiveModel::Type::Boolean.new.cast(cert_attrs[:_destroy])

        if should_destroy
          config_cert_id = find_config_certificate_for_destruction(cert_attrs)
          { id: config_cert_id, _destroy: true }.compact
        else
          cert = SignIn::Certificate.where(id: cert_attrs[:id].presence)
                                    .or(SignIn::Certificate.where(pem: cert_attrs[:pem].presence))
                                    .first

          next if certs.include?(cert)

          { cert_attributes: { id: cert&.id, pem: cert_attrs[:pem].to_s }.compact }
        end
      end
    end

    def find_config_certificate_for_destruction(cert_attrs)
      certificate_id = cert_attrs[:id].presence
      return config_certificates.where(certificate_id:).pick(:id) if certificate_id

      pem = cert_attrs[:pem].to_s.strip
      return if pem.blank?

      config_certificates.joins(:cert).where(sign_in_certificates: { pem: }).pick(:id)
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
