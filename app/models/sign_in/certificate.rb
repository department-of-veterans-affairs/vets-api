# frozen_string_literal: true

module SignIn
  class Certificate < ApplicationRecord
    self.table_name = :sign_in_certificates

    belongs_to :client_config, optional: true
    belongs_to :service_account_config, optional: true

    validates :issuer, presence: true
    validates :subject, presence: true
    validates :serial, presence: true
    validates :not_before, presence: true
    validates :not_after, presence: true
    validates :plaintext, presence: true

    validate :cannot_be_expired
    validate :cannot_be_self_signed

    def self.from_plaintext(plaintext, client_config: nil, service_account_config: nil)
      return false if plaintext.blank?

      certificate_object = OpenSSL::X509::Certificate.new(plaintext)
      new(
        issuer: certificate_object.issuer.to_s,
        subject: certificate_object.subject.to_s,
        serial: certificate_object.serial.to_s,
        not_before: certificate_object.not_before,
        not_after: certificate_object.not_after,
        plaintext:,
        client_config:,
        service_account_config:
      )
    rescue OpenSSL::X509::CertificateError
      false
    end

    def self.expired
      where('not_after < ?', Time.zone.now)
    end

    def expired?
      return false unless not_after

      not_after < Time.zone.now
    end

    def self.expiring
      where(not_after: Time.zone.now..60.days.from_now)
    end

    def self.self_signed
      where('issuer = subject')
    end

    def self_signed?
      issuer == subject
    end

    private

    def cannot_be_expired
      return unless expired?

      errors.add(:not_after, 'cannot be in the past')
    end

    def cannot_be_self_signed
      return unless self_signed?

      errors.add(:subject, 'cannot be the same as the issuer')
    end
  end
end
