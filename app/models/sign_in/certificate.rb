# frozen_string_literal: true

module SignIn
  class Certificate < ApplicationRecord
    self.table_name = 'sign_in_certificates'

    has_many :config_certificates, dependent: :destroy
    has_many :client_configs, through: :config_certificates, source: :config, source_type: 'ClientConfig'
    has_many :service_account_configs, through: :config_certificates, source: :config,
                                       source_type: 'ServiceAccountConfig'

    delegate :not_before, :not_after, :subject, :issuer, :serial, to: :certificate

    validates :pem, presence: true
    validate :validate_certificate!

    def certificate
      @certificate ||= OpenSSL::X509::Certificate.new(pem.to_s)
    rescue OpenSSL::X509::CertificateError
      nil
    end

    def expired?
      return if certificate.blank?

      not_after < Time.current
    end

    private

    def validate_certificate!
      unless certificate
        errors.add(:pem, 'not a valid X.509 certificate')
        return
      end

      errors.add(:pem, 'certificate is expired') if expired?
      errors.add(:pem, 'certificate is not yet valid') if not_before > Time.current
      errors.add(:pem, 'certificate is self-signed') if issuer == subject
    end
  end
end
