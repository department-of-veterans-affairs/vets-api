# frozen_string_literal: true

module SignIn
  class Certificate < ApplicationRecord
    self.table_name = 'sign_in_certificates'

    EXPIRING_WINDOW = 60.days

    has_many :config_certificates, dependent: :destroy
    has_many :client_configs, through: :config_certificates, source: :config, source_type: 'ClientConfig'
    has_many :service_account_configs, through: :config_certificates, source: :config,
                                       source_type: 'ServiceAccountConfig'

    delegate :not_before, :not_after, :subject, :issuer, :serial, to: :certificate

    scope :active,   -> { select(&:active?) }
    scope :expired,  -> { select(&:expired?) }
    scope :expiring, -> { select(&:expiring?) }

    validates :pem, presence: true
    validate :validate_certificate!

    def certificate
      @certificate ||= OpenSSL::X509::Certificate.new(pem.to_s)
    rescue OpenSSL::X509::CertificateError
      nil
    end

    def certificate?
      certificate.present?
    end

    def public_key
      certificate&.public_key
    end

    def expired?
      certificate? && not_after < Time.current
    end

    def expiring?
      certificate? && !expired? && not_after < EXPIRING_WINDOW.from_now
    end

    def active?
      certificate? && not_after >= EXPIRING_WINDOW.from_now
    end

    def status
      if expired?
        'expired'
      elsif expiring?
        'expiring'
      elsif active?
        'active'
      end
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
