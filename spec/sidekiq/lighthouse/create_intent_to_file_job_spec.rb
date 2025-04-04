# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/service'

RSpec.describe Lighthouse::CreateIntentToFileJob do
  let(:job) { described_class.new }
  let(:user) { create(:user) }
  let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
  let(:user_account) { create(:user_account, icn: user.icn, user_verifications: [user_verification]) }
  let(:pension_ipf) { create(:in_progress_527_form, user_account:) }
  let(:itf_type) { Lighthouse::CreateIntentToFileJob::ITF_FORMS[pension_ipf.form_id] }
  let(:service) { double('service') }
  let(:monitor) { double('monitor') }

  describe '#perform' do
    let(:response) { double('response') }

    before do
      allow(user).to receive(:participant_id).and_return('test-pid')

      allow(InProgressForm).to receive(:find).and_return(pension_ipf)

      allow(BenefitsClaims::Service).to receive(:new).and_return(service)
      allow(service).to receive(:create_intent_to_file).and_return(response)

      job.instance_variable_set(:@itf_log_monitor, monitor)
      allow(monitor).to receive :track_create_itf_begun
      allow(monitor).to receive :track_create_itf_failure
      allow(monitor).to receive :track_create_itf_success
      allow(monitor).to receive :track_create_itf_exhaustion
      allow(monitor).to receive :track_missing_user_icn
      allow(monitor).to receive :track_missing_user_pid
      allow(monitor).to receive :track_missing_form
      allow(monitor).to receive :track_invalid_itf_type
    end

    it 'successfully submits an ITF' do
      expect(monitor).to receive(:track_create_itf_begun).once
      expect(service).to receive(:create_intent_to_file).with(itf_type, '')
      expect(monitor).to receive(:track_create_itf_success).once

      # as when invoked from in_progress_form_controller
      job.perform(123, user.icn, user.participant_id)
    end

    it 'raises MissingICN' do
      allow(user).to receive(:icn).and_return nil

      expect(monitor).not_to receive(:track_create_itf_begun)
      expect(monitor).to receive(:track_missing_user_icn)

      # as when invoked from in_progress_form_controller
      job.perform(123, user.icn, user.participant_id)
    end

    it 'raises MissingParticipantIDError' do
      allow(user).to receive(:participant_id).and_return nil

      expect(monitor).not_to receive(:track_create_itf_begun)
      expect(monitor).to receive(:track_missing_user_pid)

      # as when invoked from in_progress_form_controller
      job.perform(123, user.icn, user.participant_id)
    end

    it 'raises FormNotFoundError' do
      allow(InProgressForm).to receive(:find).and_return nil

      expect(monitor).not_to receive(:track_create_itf_begun)
      expect(monitor).to receive(:track_missing_form)

      # as when invoked from in_progress_form_controller
      job.perform(123, user.icn, user.participant_id)
    end

    it 'raises InvalidITFTypeError' do
      allow(pension_ipf).to receive(:form_id).and_return 'invalid_type'

      expect(monitor).not_to receive(:track_create_itf_begun)
      expect(monitor).to receive(:track_invalid_itf_type)

      # as when invoked from in_progress_form_controller
      job.perform(123, user.icn, user.participant_id)
    end

    it 'raises other errors and logs failure' do
      allow(user_account).to receive(:icn).and_return 'non-matching-icn'

      expect(monitor).not_to receive(:track_create_itf_begun)
      expect(monitor).to receive(:track_create_itf_failure)

      # as when invoked from in_progress_form_controller
      expect { job.perform(123, user.icn, user.participant_id) }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  # Retries exhausted
  describe 'sidekiq_retries_exhausted block' do
    context 'when retries are exhausted' do
      let(:exhaustion_msg) do
        { 'args' => [pension_ipf.id, user_account.icn, 'PID'], 'class' => 'Lighthouse::CreateIntentToFileJob',
          'error_message' => 'An error occurred', 'queue' => 'default' }
      end

      before do
        allow(BenefitsClaims::IntentToFile::Monitor).to receive(:new).and_return(monitor)
        allow(InProgressForm).to receive(:find).and_return(pension_ipf)
      end

      it 'logs a distinct error when form_type, form_start_date, and veteran_icn provided' do
        Lighthouse::CreateIntentToFileJob.within_sidekiq_retries_exhausted_block(
          exhaustion_msg, 'TESTERROR'
        ) do
          expect(monitor).to receive(:track_create_itf_exhaustion).with('pension', pension_ipf, 'TESTERROR')
        end
      end
    end
  end
end
