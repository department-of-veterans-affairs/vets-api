# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BPDS::SubmitToBPDSJob, type: :job do
  let(:bpds_submission) { create(:bpds_submission) }
  let(:bpds_submission_attempt) { double(BPDS::SubmissionAttempt) }
  let(:monitor) { double(BPDS::Monitor) }
  let(:service) { double(BPDS::Service) }
  let(:response) { { 'uuid' => '12345' } }

  before do
    allow(BPDS::Submission).to receive(:find_by).with(id: bpds_submission.id).and_return(bpds_submission)
    # rubocop:disable RSpec/MessageChain
    allow(bpds_submission)
      .to receive_message_chain(:submission_attempts, :create).and_return(bpds_submission_attempt)
    # rubocop:enable RSpec/MessageChain
    allow(BPDS::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:track_submit_begun)
    allow(monitor).to receive(:track_submit_success)
    allow(monitor).to receive(:track_submit_failure)
    allow(BPDS::Service).to receive(:new).and_return(service)
  end

  describe '#perform' do
    context 'when the submission is successful' do
      before do
        allow(service).to receive(:submit_json).with(bpds_submission.saved_claim).and_return(response)
        allow(bpds_submission_attempt).to receive(:update)
      end

      it 'submits the BPDS submission and updates the attempt' do
        described_class.new.perform(bpds_submission.id)

        expect(service).to have_received(:submit_json).with(bpds_submission.saved_claim)
        expect(bpds_submission_attempt).to have_received(:update).with(
          status: 'submitted',
          response: response.to_json,
          bpds_id: response['uuid']
        )
        expect(monitor).to have_received(:track_submit_success).with(bpds_submission.saved_claim_id)
      end
    end

    context 'when the submission fails' do
      let(:error) { StandardError.new('Submission failed') }

      before do
        allow(service).to receive(:submit_json).and_raise(error)
        allow(bpds_submission_attempt).to receive(:update)
      end

      it 'updates the attempt with failure and raises the error' do
        expect do
          described_class.new.perform(bpds_submission.id)
        end.to raise_error(StandardError, 'Submission failed')

        expect(bpds_submission_attempt).to have_received(:update).with(
          status: 'failure',
          error_message: 'Submission failed'
        )
        expect(monitor).to have_received(:track_submit_failure).with(bpds_submission.saved_claim_id, error)
      end
    end
  end

  describe '.sidekiq_retries_exhausted' do
    let(:msg) { { 'args' => [bpds_submission.id] } }
    let(:error) { StandardError.new('Retries exhausted') }

    before do
      allow(Rails.logger).to receive(:error)
    end

    it 'logs the error and creates a failed submission attempt' do
      described_class.sidekiq_retries_exhausted_block.call(msg, error)

      expect(Rails.logger).to have_received(:error).with(
        "SubmitToBPDSJob exhausted all retries for BPDS Submission ID: #{bpds_submission.id}"
      )
      expect(bpds_submission.submission_attempts).to have_received(:create).with(
        status: 'failure',
        error_message: 'Retries exhausted'
      )
    end
  end
end
