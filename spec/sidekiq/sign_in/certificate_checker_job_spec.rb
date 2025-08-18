# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CertificateCheckerJob, type: :job do
  subject(:job) { described_class.new }

  before do
    allow(Rails.logger).to receive(:warn)
  end

  describe '#perform' do
    %i[service_account_config client_config].each do |factory_name|
      context "for #{factory_name.to_s.humanize} configs" do
        let(:config) { create(factory_name) }

        context 'with no certificates' do
          it 'does not log any alerts' do
            job.perform
            expect(Rails.logger).not_to have_received(:warn)
          end
        end

        context 'with only an active certificate' do
          let(:active_certificate) { create(:sign_in_certificate) }

          before do
            config.certs << active_certificate
            config.save(validate: false)
          end

          it 'does not log any alerts' do
            job.perform
            expect(Rails.logger).not_to have_received(:warn)
          end
        end

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
              hash_including(
                config_type: config.class.name,
                config_id: config.id,
                config_description: config.description,
                certificate_subject: expired_certificate.subject.to_s,
                certificate_issuer: expired_certificate.issuer.to_s,
                certificate_serial: expired_certificate.serial.to_s,
                certificate_not_before: expired_certificate.not_before.to_s,
                certificate_not_after: expired_certificate.not_after.to_s
              )
            )
          end

          context 'and an active certificate exists' do
            let(:active_certificate) { create(:sign_in_certificate) }

            before do
              config.certs << active_certificate
              config.save(validate: false)
            end

            it 'does not log an alert for the expired certificate' do
              job.perform
              expect(Rails.logger).not_to have_received(:warn).with(
                '[SignIn] [CertificateChecker] expired_certificate',
                anything
              )
            end
          end

          context 'and an expiring certificate exists' do
            let(:expiring_certificate) { create(:sign_in_certificate, :expiring) }

            before do
              config.certs << expiring_certificate
              config.save(validate: false)
            end

            it 'does not log an alert for the expired certificate' do
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
              hash_including(
                config_type: config.class.name,
                config_id: config.id,
                config_description: config.description,
                certificate_subject: expiring_certificate.subject.to_s,
                certificate_issuer: expiring_certificate.issuer.to_s,
                certificate_serial: expiring_certificate.serial.to_s,
                certificate_not_before: expiring_certificate.not_before.to_s,
                certificate_not_after: expiring_certificate.not_after.to_s
              )
            )
          end

          context 'and an active certificate exists' do
            let(:active_certificate) { create(:sign_in_certificate) }

            before do
              config.certs << active_certificate
              config.save(validate: false)
            end

            it 'does not log an alert for the expiring certificate' do
              job.perform
              expect(Rails.logger).not_to have_received(:warn).with(
                '[SignIn] [CertificateChecker] expiring_certificate',
                anything
              )
            end
          end

          context 'and an expired certificate exists' do
            let(:expired_certificate) { build(:sign_in_certificate, :expired) }

            before do
              expired_certificate.save(validate: false)
              config.certs << expired_certificate
              config.save(validate: false)
            end

            it 'logs only for the expiring certificate' do
              job.perform

              expect(Rails.logger).to have_received(:warn).with(
                '[SignIn] [CertificateChecker] expiring_certificate',
                hash_including(certificate_serial: expiring_certificate.serial.to_s)
              )
              expect(Rails.logger).not_to have_received(:warn).with(
                '[SignIn] [CertificateChecker] expired_certificate',
                anything
              )
            end
          end
        end

        context 'with multiple expired certificates' do
          let(:expired_cert1) { build(:sign_in_certificate, :expired) }
          let(:expired_cert2) { build(:sign_in_certificate, :expired) }

          before do
            expired_cert1.save(validate: false)
            expired_cert2.save(validate: false)
            config.certs << expired_cert1 << expired_cert2
            config.save(validate: false)
          end

          it 'logs an alert for each expired certificate when no active or expiring exist' do
            job.perform

            expect(Rails.logger).to have_received(:warn).with(
              '[SignIn] [CertificateChecker] expired_certificate',
              hash_including(certificate_serial: expired_cert1.serial.to_s)
            )
            expect(Rails.logger).to have_received(:warn).with(
              '[SignIn] [CertificateChecker] expired_certificate',
              hash_including(certificate_serial: expired_cert2.serial.to_s)
            )
          end
        end
      end
    end
  end
end
