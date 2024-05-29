# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CertificateCheckerJob, type: :job do
  subject(:job) { described_class.new }

  describe '#perform' do
    subject(:perform) { job.perform }

    let!(:client_config) { create(:client_config, certificates: client_config_certificates) }
    let(:client_config_certificates) { [valid_certificate] }
    let!(:service_account_config) { create(:service_account_config, certificates: service_account_config_certificates) }
    let(:service_account_config_certificates) { [valid_certificate] }
    let(:valid_certificate) do
      File.read('spec/fixtures/sign_in/sample_client.crt')
    end

    before do
      allow(Rails.logger).to receive(:warn)
    end

    context 'when all configurations have valid certificates' do
      it 'does not log any alerts' do
        perform
        expect(Rails.logger).not_to receive(:warn)
      end
    end

    shared_examples 'alerts for any expired certificates' do
      it 'logs an alert' do
        perform
        certificate_object = OpenSSL::X509::Certificate.new(expired_certificate)
        expect(Rails.logger).to have_received(:warn).with(
          '[SignIn] [CertificateChecker] expired_certificate',
          {
            config_type: subject.class.name,
            config_id: subject.id,
            config_description: subject.description,
            certificate_subject: certificate_object.subject.to_s,
            certificate_issuer: certificate_object.issuer.to_s,
            certificate_serial: certificate_object.serial.to_s,
            certificate_not_before: certificate_object.not_before.to_s,
            certificate_not_after: certificate_object.not_after.to_s
          }
        )
      end
    end

    shared_examples 'alerts for any expiring certificates' do
      it 'logs an alert' do
        perform
        certificate_object = OpenSSL::X509::Certificate.new(expiring_certificate)
        expect(Rails.logger).to have_received(:warn).with(
          '[SignIn] [CertificateChecker] expiring_certificate',
          {
            config_type: subject.class.name,
            config_id: subject.id,
            config_description: subject.description,
            certificate_subject: certificate_object.subject.to_s,
            certificate_issuer: certificate_object.issuer.to_s,
            certificate_serial: certificate_object.serial.to_s,
            certificate_not_before: certificate_object.not_before.to_s,
            certificate_not_after: certificate_object.not_after.to_s
          }
        )
      end
    end

    shared_examples 'alerts for any self-signed certificates' do
      it 'logs an alert' do
        perform
        certificate_object = OpenSSL::X509::Certificate.new(self_signed_certificate)
        expect(Rails.logger).to have_received(:warn).with(
          '[SignIn] [CertificateChecker] self_signed_certificate',
          {
            config_type: subject.class.name,
            config_id: subject.id,
            config_description: subject.description,
            certificate_subject: certificate_object.subject.to_s,
            certificate_issuer: certificate_object.issuer.to_s,
            certificate_serial: certificate_object.serial.to_s,
            certificate_not_before: certificate_object.not_before.to_s,
            certificate_not_after: certificate_object.not_after.to_s
          }
        )
      end
    end

    context 'when a client configuration has an expired certificate' do
      subject { client_config }

      let(:client_config_certificates) { [valid_certificate, expired_certificate] }
      let(:expired_certificate) do
        File.read('spec/fixtures/sign_in/sample_expired_client.crt')
      end

      it_behaves_like 'alerts for any expired certificates'
    end

    context 'when a service account configuration has an expired certificate' do
      subject { service_account_config }

      let(:service_account_config_certificates) { [valid_certificate, expired_certificate] }
      let(:expired_certificate) do
        File.read('spec/fixtures/sign_in/sample_expired_client.crt')
      end

      it_behaves_like 'alerts for any expired certificates'
    end

    context 'when a client configuration has an expiring certificate' do
      subject { client_config }

      let(:client_config_certificates) { [valid_certificate, expiring_certificate] }
      let(:expiring_certificate) do
        File.read('spec/fixtures/sign_in/sample_expired_client.crt')
      end

      it_behaves_like 'alerts for any expiring certificates'
    end

    context 'when a service account configuration has an expiring certificate' do
      subject { service_account_config }

      let(:service_account_config_certificates) { [valid_certificate, expiring_certificate] }
      let(:expiring_certificate) do
        File.read('spec/fixtures/sign_in/sample_expired_client.crt')
      end

      it_behaves_like 'alerts for any expiring certificates'
    end

    context 'when a client configuration has a self-signed certificate' do
      subject { client_config }

      let(:client_config_certificates) { [valid_certificate, self_signed_certificate] }
      let(:self_signed_certificate) do
        File.read('spec/fixtures/sign_in/sample_self_signed_client.crt')
      end

      it_behaves_like 'alerts for any self-signed certificates'
    end

    context 'when a service account configuration has a self-signed certificate' do
      subject { service_account_config }

      let(:service_account_config_certificates) { [valid_certificate, self_signed_certificate] }
      let(:self_signed_certificate) do
        File.read('spec/fixtures/sign_in/sample_self_signed_client.crt')
      end

      it_behaves_like 'alerts for any self-signed certificates'
    end
  end
end
