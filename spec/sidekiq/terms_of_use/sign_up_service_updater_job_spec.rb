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

    it 'retries 5 times after failure' do
      expect(described_class.get_sidekiq_options['retry']).to eq(5)
    end

    it 'logs a message when retries have been exhausted' do
      logger_spy = instance_spy(ActiveSupport::Logger)
      allow(Rails).to receive(:logger).and_return(logger_spy)

      job_info = { 'class' => described_class.to_s, 'args' => %w[foo bar] }
      error_message = 'foobar'
      described_class.sidekiq_retries_exhausted_block.call(
        job_info, Common::Client::Errors::ClientError.new(error_message)
      )

      expect(logger_spy)
        .to have_received(:warn)
        .with(
          "[TermsOfUse][SignUpServiceUpdaterJob] Retries exhausted for #{job_info['class']} " \
          "with args #{job_info['args']}: #{error_message}"
        )
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
