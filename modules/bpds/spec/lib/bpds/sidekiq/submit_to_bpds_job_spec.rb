# frozen_string_literal: true

require 'rails_helper'
require 'bpds/service'
require 'bpds/monitor'
require 'bpds/submission'
require 'bpds/submission_attempt'
require 'bpds/sidekiq/submit_to_bpds_job'

RSpec.describe BPDS::Sidekiq::SubmitToBPDSJob, type: :job do
  let(:claim) { create(:pensions_saved_claim) }
  let(:participant_id) { '600061742' }
  let(:file_number) { '123123123' }
  let(:encrypted_payload) { KmsEncrypted::Box.new.encrypt({ 'participant_id' => participant_id }.to_json) }
  let(:encrypted_payload_file_number) { KmsEncrypted::Box.new.encrypt({ 'file_number' => file_number }.to_json) }
  let(:bpds_submission) { create(:bpds_submission, saved_claim: claim) }
  let(:bpds_submission_attempt) { double(BPDS::SubmissionAttempt) }
  let(:monitor) { double(BPDS::Monitor) }
  let(:service) { double(BPDS::Service) }
  let(:response) { { 'uuid' => '12345' } }

  before do
    allow(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
    allow(BPDS::Submission).to receive(:find_or_create_by).and_return(bpds_submission)
    # rubocop:disable RSpec/MessageChain
    allow(bpds_submission).to receive_message_chain(:submission_attempts, :create).and_return(bpds_submission_attempt)
    # rubocop:enable RSpec/MessageChain
    allow(BPDS::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:track_submit_success)
    allow(monitor).to receive(:track_submit_failure)
    allow(BPDS::Service).to receive(:new).and_return(service)
    allow(service).to receive(:submit_json).and_return(response)
    allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(true)
  end

  describe '#perform' do
    context 'when the feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(false)
      end

      it 'does not perform the job' do
        expect(described_class.new.perform(claim.id, encrypted_payload)).to be_nil
        expect(service).not_to have_received(:submit_json)
      end
    end

    context 'when the submission is successful' do
      before do
        allow(service).to receive(:submit_json).with(claim).and_return(response)
      end

      context 'and participant_id is provided' do
        it 'submits the BPDS submission and creates a successful attempt' do
          described_class.new.perform(claim.id, encrypted_payload)

          expect(service).to have_received(:submit_json).with(claim, participant_id, nil)
          expect(bpds_submission.submission_attempts).to have_received(:create).with(
            status: 'submitted',
            response: response.to_json,
            bpds_id: response['uuid']
          )
          expect(monitor).to have_received(:track_submit_success).with(claim.id)
        end
      end

      context 'and file_number is provided' do
        it 'submits the BPDS submission and creates a successful attempt' do
          described_class.new.perform(claim.id, encrypted_payload_file_number)

          expect(service).to have_received(:submit_json).with(claim, nil, file_number)
          expect(bpds_submission.submission_attempts).to have_received(:create).with(
            status: 'submitted',
            response: response.to_json,
            bpds_id: response['uuid']
          )
          expect(monitor).to have_received(:track_submit_success).with(claim.id)
        end
      end
    end

    context 'when the claim has already been submitted' do
      before do
        allow(bpds_submission).to receive(:latest_status).and_return('submitted')
        allow(Rails.logger).to receive(:info)
      end

      it 'logs that the claim has already been submitted' do
        described_class.new.perform(claim.id, encrypted_payload)

        expect(Rails.logger).to have_received(:info).with(
          "Saved Claim #:#{claim.id} has already been submitted to BPDS"
        )
      end
    end

    context 'when the submission fails' do
      let(:error) { StandardError.new('Submission failed') }

      before do
        allow(service).to receive(:submit_json).and_raise(error)
      end

      it 'creates a failure attempt and raises the error' do
        expect do
          described_class.new.perform(claim.id, encrypted_payload)
        end.to raise_error(StandardError, 'Submission failed')

        expect(bpds_submission.submission_attempts).to have_received(:create).with(
          status: 'failure',
          error_message: 'Submission failed'
        )
        expect(monitor).to have_received(:track_submit_failure).with(claim.id, error)
      end
    end
  end

  describe '.sidekiq_retries_exhausted' do
    let(:msg) { { 'args' => [claim.id] } }
    let(:error) { StandardError.new('Retries exhausted') }

    before do
      allow(Rails.logger).to receive(:error)
      allow(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
      allow(BPDS::Submission).to receive(:find_by).with(saved_claim: claim).and_return(bpds_submission)
    end

    it 'logs the error and creates a failed submission attempt' do
      described_class.sidekiq_retries_exhausted_block.call(msg, error)

      expect(Rails.logger).to have_received(:error).with(
        "SubmitToBPDSJob exhausted all retries for saved claim ID: #{claim.id}"
      )
      expect(bpds_submission.submission_attempts).to have_received(:create).with(
        status: 'failure',
        error_message: 'Retries exhausted'
      )
    end
  end
end
