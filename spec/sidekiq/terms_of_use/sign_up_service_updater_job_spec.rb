# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::SignUpServiceUpdaterJob, type: :job do
  describe '#perform' do
    subject(:job) { described_class.new }

    let(:user_account) { create(:user_account) }
    let(:icn) { user_account.icn }
    let(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response:) }
    let(:response) { 'accepted' }
    let(:common_name) { 'some-common-name' }
    let(:service_instance) { instance_double(MAP::SignUp::Service) }
    let(:version) { terms_of_use_agreement.agreement_version }
    let(:attr_package_key) { Digest::SHA256.hexdigest(attr_package.to_json) }
    let(:attr_package) { { icn: user_account.icn, signature_name: common_name, version: } }

    before do
      allow(MAP::SignUp::Service).to receive(:new).and_return(service_instance)
      allow(Sidekiq::AttrPackage).to receive(:create).and_return(attr_package_key)
      allow(Sidekiq::AttrPackage).to receive(:find).with(attr_package_key).and_return(attr_package)
      allow(Sidekiq::AttrPackage).to receive(:delete)
    end

    it 'retries for 47 hours after failure' do
      expect(described_class.get_sidekiq_options['retry_for']).to eq(47.hours)
    end

    context 'when retries have been exhausted' do
      let(:job) { { args: [attr_package_key] }.as_json }
      let(:exception_message) { 'some-error' }
      let(:exception) { StandardError.new(exception_message) }
      let(:expected_log_message) { '[TermsOfUse][SignUpServiceUpdaterJob] retries exhausted' }
      let(:expected_log_payload) { { icn:, exception_message:, attr_package_key: } }

      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs a warning message with the expected payload' do
        described_class.sidekiq_retries_exhausted_block.call(job, exception)

        expect(Rails.logger).to have_received(:warn).with(expected_log_message, expected_log_payload)
      end
    end

    context 'when the terms of use agreement is accepted' do
      before do
        allow(service_instance).to receive(:agreements_accept)
      end

      it 'updates the terms of use agreement in sign up service' do
        job.perform(attr_package_key)

        expect(MAP::SignUp::Service).to have_received(:new)
        expect(service_instance).to have_received(:agreements_accept).with(icn: user_account.icn,
                                                                           signature_name: common_name,
                                                                           version:)
      end

      it 'deletes the attribute package' do
        job.perform(attr_package_key)

        expect(Sidekiq::AttrPackage).to have_received(:delete).with(attr_package_key)
      end
    end

    context 'when the terms of use agreement is declined' do
      let(:response) { 'declined' }

      before do
        allow(service_instance).to receive(:agreements_decline)
      end

      it 'updates the terms of use agreement in sign up service' do
        job.perform(attr_package_key)

        expect(MAP::SignUp::Service).to have_received(:new)
        expect(service_instance).to have_received(:agreements_decline).with(icn: user_account.icn)
      end

      it 'deletes the attribute package' do
        job.perform(attr_package_key)

        expect(Sidekiq::AttrPackage).to have_received(:delete).with(attr_package_key)
      end
    end

    context 'when MAP::SignUp::Service service fails' do
      before do
        allow(service_instance).to receive(:agreements_accept).and_raise(StandardError)
      end

      it 'does not delete the attribute package' do
        expect { job.perform(attr_package_key) }.to raise_error(StandardError)
        expect(Sidekiq::AttrPackage).not_to have_received(:delete).with(attr_package_key)
      end
    end
  end
end
