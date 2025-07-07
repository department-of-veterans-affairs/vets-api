# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CertificateCheckerJob, type: :job do
  subject(:job) { described_class.new }

  before do
    allow(Rails.logger).to receive(:warn)
  end

  describe '#perform' do
    context 'when all configurations have valid certificates' do
      it 'does not log any alerts' do
        job.perform
        expect(Rails.logger).not_to have_received(:warn)
      end
    end

    %i[service_account_config client_config].each do |factory_name|
      context "when there are #{factory_name.to_s.pluralize}" do
        let(:config) { create(factory_name) }

        context 'with an expired certificate' do
          let(:expired_certificate) { build(:sign_in_certificate, :expired) }

          before do
            expired_certificate.save(validate: false)
            config.certs << expired_certificate
            config.save(validate: false)
          end

          it 'logs an alert for the expired certificate' do
            job.perform

            expect(Rails.logger).to have_received(:warn).with(
              '[SignIn] [CertificateChecker] expired_certificate',
              config_type: config.class.name,
              config_id: config.id,
              config_description: config.description,
              certificate_subject: expired_certificate.subject.to_s,
              certificate_issuer: expired_certificate.issuer.to_s,
              certificate_serial: expired_certificate.serial.to_s,
              certificate_not_before: expired_certificate.not_before.to_s,
              certificate_not_after: expired_certificate.not_after.to_s
            )
          end

          context 'and it also has an active certificate' do
            let(:active_certificate) { create(:sign_in_certificate) }

            before do
              config.certs << active_certificate
              config.save(validate: false)
            end

            it 'does not log an alert for the expired certificate when an active one exists' do
              job.perform

              expect(Rails.logger).not_to have_received(:warn).with(
                '[SignIn] [CertificateChecker] expired_certificate',
                anything
              )
            end
          end
        end

        context 'with an expiring certificate' do
          let(:expiring_certificate) { create(:sign_in_certificate, :expiring) }

          before do
            config.certs << expiring_certificate
            config.save(validate: false)
          end

          it 'logs an alert for the expiring certificate' do
            job.perform

            expect(Rails.logger).to have_received(:warn).with(
              '[SignIn] [CertificateChecker] expiring_certificate',
              config_type: config.class.name,
              config_id: config.id,
              config_description: config.description,
              certificate_subject: expiring_certificate.subject.to_s,
              certificate_issuer: expiring_certificate.issuer.to_s,
              certificate_serial: expiring_certificate.serial.to_s,
              certificate_not_before: expiring_certificate.not_before.to_s,
              certificate_not_after: expiring_certificate.not_after.to_s
            )
          end
        end
      end
    end
  end
end
