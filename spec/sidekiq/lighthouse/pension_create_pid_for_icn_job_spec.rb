# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::PensionCreatePidForIcnJob, type: :job do
  let(:form_type) { 'some_form_type' }
  let(:form_start_date) { Time.zone.today }
  let(:veteran_icn) { '1234567890' }
  let(:user_account) { create(:user_account, icn: veteran_icn) }
  let(:adder_service) { instance_double(MPIProxyPersonAdder) }

  before do
    allow(UserAccount).to receive(:find_by).with(icn: veteran_icn).and_return(user_account)
    allow(MPIProxyPersonAdder).to receive(:new).with(veteran_icn).and_return(adder_service)
    allow(adder_service).to receive(:add_person_proxy_by_icn).and_return(true)
    allow(Lighthouse::CreateIntentToFileJob).to receive(:perform_async)
  end

  describe '#perform' do
    it 'calls add_person_proxy_by_icn on MPIProxyPersonAdder' do
      expect(adder_service).to receive(:add_person_proxy_by_icn)
      subject.perform(form_type, form_start_date, veteran_icn)
    end

    context 'when add_person_proxy_by_icn returns true' do
      it 'calls CreateIntentToFileJob.perform_async' do
        expect(Lighthouse::CreateIntentToFileJob).to receive(:perform_async).with(form_type, form_start_date,
                                                                                  veteran_icn)
        subject.perform(form_type, form_start_date, veteran_icn)
      end
    end

    context 'when add_person_proxy_by_icn returns false' do
      before do
        allow(adder_service).to receive(:add_person_proxy_by_icn).and_return(false)
      end

      it 'does not call CreateIntentToFileJob.perform_async' do
        expect(Lighthouse::CreateIntentToFileJob).not_to receive(:perform_async)
        subject.perform(form_type, form_start_date, veteran_icn)
      end
    end

    context 'when ArgumentError or MPI::Errors::RecordNotFound is raised' do
      let(:error) { ArgumentError.new('some error') }

      before do
        allow(adder_service).to receive(:add_person_proxy_by_icn).and_raise(error)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:error).with(
          'PensionCreatePidForIcnJob caught exception not meant for retry. ITF auto creation cancelled.',
          { error: }
        )
        subject.perform(form_type, form_start_date, veteran_icn)
      end
    end
  end

  describe 'sidekiq_options' do
    it 'has the correct retry value' do
      expect(described_class.sidekiq_options['retry']).to eq(14)
    end

    it 'has the correct queue value' do
      expect(described_class.sidekiq_options['queue']).to eq('low')
    end
  end

  describe 'sidekiq_retries_exhausted' do
    let(:msg) { { 'args' => [form_type, form_start_date, veteran_icn] } }
    let(:error) { StandardError.new('Some error') }

    it 'calls UserAccount.find_by with the correct icn' do
      described_class.within_sidekiq_retries_exhausted_block(msg, error) do
        expect(UserAccount).to receive(:find_by).with(icn: veteran_icn).and_return(user_account)
      end
    end

    it 'calls track_proxy_add_exhaustion with the correct arguments' do
      described_class.within_sidekiq_retries_exhausted_block(msg, error) do
        expect(Rails.logger).to receive(:error).with(
          'Add person proxy by icn retries exhausted',
          {
            error:,
            form_start_date:,
            form_type:,
            user_account_uuid: user_account.id
          }
        )
      end
    end
  end
end
