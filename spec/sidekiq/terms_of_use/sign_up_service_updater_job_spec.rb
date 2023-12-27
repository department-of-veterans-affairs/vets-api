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

    before do
      allow(MAP::SignUp::Service).to receive(:new).and_return(service_instance)
    end

    it 'retries 15 times after failure' do
      expect(described_class.get_sidekiq_options['retry']).to eq(15)
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

    it { is_expected.to be_unique }

    context 'when the terms of use agreement is accepted' do
      let(:attr_key) do
        Digest::SHA256.hexdigest({ icn: user_account.icn, signature_name: common_name, version: }.to_json)
      end

      before do
        allow(service_instance).to receive(:agreements_accept)
        allow(Sidekiq::AttrPackage).to receive(:create).and_return(attr_key)
        allow(Sidekiq::AttrPackage).to receive(:find).with(attr_key).and_return({ icn: user_account.icn,
                                                                                  signature_name: common_name,
                                                                                  version: })
      end

      it 'updates the terms of use agreement in sign up service' do
        job.perform(attr_key)

        expect(MAP::SignUp::Service).to have_received(:new)
        expect(service_instance).to have_received(:agreements_accept).with(icn: user_account.icn,
                                                                           signature_name: common_name,
                                                                           version:)
      end
    end

    context 'when the terms of use agreement is declined' do
      let(:attr_key) do
        Digest::SHA256.hexdigest({ icn: user_account.icn, signature_name: common_name, version: }.to_json)
      end
      let(:response) { 'declined' }

      before do
        allow(service_instance).to receive(:agreements_decline)
        allow(Sidekiq::AttrPackage).to receive(:create).and_return(attr_key)
        allow(Sidekiq::AttrPackage).to receive(:find).with(attr_key).and_return({ icn: user_account.icn,
                                                                                  signature_name: common_name,
                                                                                  version: })
      end

      it 'updates the terms of use agreement in sign up service' do
        job.perform(attr_key)

        expect(MAP::SignUp::Service).to have_received(:new)
        expect(service_instance).to have_received(:agreements_decline).with(icn: user_account.icn)
      end
    end
  end
end
