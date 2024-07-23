# frozen_string_literal: true

class SignIn::CertificateCheckerJob
  include Sidekiq::Job

  def perform(*_args)
    client_configs = SignIn::ClientConfig.all
    check_certificates_for(client_configs)

    service_account_configs = SignIn::ServiceAccountConfig.all
    check_certificates_for(service_account_configs)
  end

  private

  def check_certificates_for(configs)
    configs.find_each do |config|
      config.expired_certificates.each do |certificate|
        payload = payload_for_alert(config, certificate)
        Rails.logger.warn('[SignIn] [CertificateChecker] expired_certificate', payload)
      end

      config.expiring_certificates.each do |certificate|
        payload = payload_for_alert(config, certificate)
        Rails.logger.warn('[SignIn] [CertificateChecker] expiring_certificate', payload)
      end

      config.self_signed_certificates.each do |certificate|
        payload = payload_for_alert(config, certificate)
        Rails.logger.warn('[SignIn] [CertificateChecker] self_signed_certificate', payload)
      end
    end
  end

  def payload_for_alert(config, certificate)
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
