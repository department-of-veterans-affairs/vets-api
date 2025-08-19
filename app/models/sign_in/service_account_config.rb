# frozen_string_literal: true

module SignIn
  class ServiceAccountConfig < ApplicationRecord
    attribute :access_token_duration, :interval

    has_many :config_certificates, as: :config, dependent: :destroy, inverse_of: :config
    has_many :certs, through: :config_certificates,
                     class_name: 'SignIn::Certificate',
                     inverse_of: :service_account_configs,
                     index_errors: true

    accepts_nested_attributes_for :certs,
                                  allow_destroy: true,
                                  reject_if: ->(attrs) { attrs['pem'].blank? && attrs['id'].blank? }

    validates :service_account_id, presence: true, uniqueness: true
    validates :description, presence: true
    validates :access_token_audience, presence: true
    validates :access_token_duration,
              presence: true,
              inclusion: { in: Constants::ServiceAccountAccessToken::VALIDITY_LENGTHS, allow_nil: false }
    validates :access_token_user_attributes, inclusion: { in: Constants::ServiceAccountAccessToken::USER_ATTRIBUTES }

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
  end
end
