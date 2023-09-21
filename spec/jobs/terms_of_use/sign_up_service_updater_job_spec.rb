# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::SignUpServiceUpdaterJob, type: :job do
  describe '#perform' do
    subject(:job) { described_class.new }

    let(:user_account) { create(:user_account) }
    let(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response:) }
    let(:response) { 'accepted' }
    let(:common_name) { 'some-common-name' }
    let(:service_instance) { instance_double(MobileApplicationPlatform::SignUp::Service) }
    let(:version) { terms_of_use_agreement.agreement_version }

    before do
      allow(MobileApplicationPlatform::SignUp::Service).to receive(:new).and_return(service_instance)
    end

    it 'retries 15 times after failure' do
      expect(described_class.get_sidekiq_options['retry']).to eq(15)
    end

    it 'logs a message when retries have been exhausted' do
      logger_spy = instance_spy(ActiveSupport::Logger)
      allow(Rails).to receive(:logger).and_return(logger_spy)

      job_info = { 'name' => described_class.to_s, 'args' => %w[foo bar] }
      error_message = 'foobar'
      described_class.sidekiq_retries_exhausted_block.call(
        job_info, Common::Client::Errors::ClientError.new(error_message)
      )

      expect(logger_spy)
        .to have_received(:warn)
        .with(
          "[TermsOfUse][SignUpServiceUpdaterJob] Retries exhausted for #{job_info['name']} " \
          "with args #{job_info['args']}: #{error_message}"
        )
    end

    context 'when the terms of use agreement is accepted' do
      before do
        allow(service_instance).to receive(:agreements_accept)
      end

      it 'updates the terms of use agreement in sign up service' do
        job.perform(terms_of_use_agreement.id, common_name)

        expect(MobileApplicationPlatform::SignUp::Service).to have_received(:new)
        expect(service_instance).to have_received(:agreements_accept).with(icn: user_account.icn,
                                                                           signature_name: common_name,
                                                                           version:)
      end
    end

    context 'when the terms of use agreement is declined' do
      let(:response) { 'declined' }

      before do
        allow(service_instance).to receive(:agreements_decline)
      end

      it 'updates the terms of use agreement in sign up service' do
        job.perform(terms_of_use_agreement.id, common_name)

        expect(MobileApplicationPlatform::SignUp::Service).to have_received(:new)
        expect(service_instance).to have_received(:agreements_decline).with(icn: user_account.icn)
      end
    end
  end
end
