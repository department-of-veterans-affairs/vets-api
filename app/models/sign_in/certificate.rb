# frozen_string_literal: true

module SignIn
  class Certificate < ApplicationRecord
    self.table_name = 'sign_in_certificates'

    EXPIRING_WINDOW = 60.days

    has_many :config_certificates, dependent: :destroy
    has_many :client_configs, through: :config_certificates, source: :config, source_type: 'ClientConfig'
    has_many :service_account_configs, through: :config_certificates, source: :config,
                                       source_type: 'ServiceAccountConfig'

    delegate :not_before, :not_after, :subject, :issuer, :serial, to: :x509

    scope :active,   -> { select(&:active?) }
    scope :expired,  -> { select(&:expired?) }
    scope :expiring_soon, -> { select(&:expiring_soon?) }
    scope :expiring_later, -> { select(&:expiring_later?) }

    normalizes :pem, with: ->(value) { value.present? ? "#{value.chomp}\n" : value }

    validates :pem, presence: true
    validate :validate_x509

    def x509
      @x509 ||= OpenSSL::X509::Certificate.new(pem.to_s)
    rescue OpenSSL::X509::CertificateError
      nil
    end

    def x509?
      x509.present?
    end

    def public_key
      x509&.public_key
    end

    def expired?
      x509? && not_after < Time.current
    end

    def expiring_soon?
      x509? && !expired? && not_after <= EXPIRING_WINDOW.from_now
    end

    def expiring_later?
      x509? && not_after > EXPIRING_WINDOW.from_now
    end

    def active?
      x509? && not_after > Time.current
    end

    def status
      if expired?
        'expired'
      elsif expiring_soon?
        'expiring_soon'
      elsif active?
        'active'
      end
    end

    private

    def validate_x509
      unless x509
        errors.add(:pem, 'not a valid X.509 certificate')
        return
      end

      errors.add(:pem, 'X.509 certificate is expired') if expired?
      errors.add(:pem, 'X.509 certificate is not yet valid') if not_before > Time.current
      errors.add(:pem, 'X.509 certificate is self-signed') if issuer == subject
    end
  end
end
