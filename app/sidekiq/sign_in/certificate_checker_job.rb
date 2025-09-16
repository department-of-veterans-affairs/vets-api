# frozen_string_literal: true

class SignIn::CertificateCheckerJob
  include Sidekiq::Job

  LOGGER_PREFIX = '[SignIn] [CertificateChecker]'
  CONFIG_CLASSES = [
    SignIn::ClientConfig,
    SignIn::ServiceAccountConfig
  ].freeze

  def perform
    CONFIG_CLASSES.each do |config_class|
      config_class.find_each { |config| check_certificates(config) }
    end
  end

  private

  def check_certificates(config)
    return if config.certs.expiring_later.any?

    if config.certs.expiring_soon.any?
      log_expiring_soon_certs(config)
    elsif config.certs.expired.any?
      log_expired_certs(config)
    end
  end

  def log_expired_certs(config)
    config.certs.expired.each do |cert|
      log_warning('expired_certificate', config, cert)
    end
  end

  def log_expiring_soon_certs(config)
    config.certs.expiring_soon.each do |cert|
      log_warning('expiring_soon_certificate', config, cert)
    end
  end

  def log_warning(type, config, certificate)
    Rails.logger.warn(
      "#{LOGGER_PREFIX} #{type}", build_payload(config, certificate)
    )
  end

  def build_payload(config, certificate)
    {
      config_type: config.class.name,
      config_id: config.id,
      config_description: config.description,
      certificate_subject: certificate.subject.to_s,
      certificate_issuer: certificate.issuer.to_s,
      certificate_serial: certificate.serial.to_s,
      certificate_not_before: certificate.not_before.to_s,
      certificate_not_after: certificate.not_after.to_s
    }
  end
end
