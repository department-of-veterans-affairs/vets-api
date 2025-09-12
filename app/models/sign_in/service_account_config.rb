# frozen_string_literal: true

module SignIn
  class ServiceAccountConfig < ApplicationRecord
    attribute :access_token_duration, :interval

    has_many :config_certificates, as: :config, dependent: :destroy, inverse_of: :config, index_errors: true
    has_many :certs, through: :config_certificates, source: :cert, index_errors: true

    accepts_nested_attributes_for :config_certificates, allow_destroy: true

    validates :service_account_id, presence: true, uniqueness: true
    validates :description, presence: true
    validates :access_token_audience, presence: true
    validates :access_token_duration,
              presence: true,
              inclusion: { in: Constants::ServiceAccountAccessToken::VALIDITY_LENGTHS, allow_nil: false }
    validates :access_token_user_attributes, inclusion: { in: Constants::ServiceAccountAccessToken::USER_ATTRIBUTES }

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
  end
end
