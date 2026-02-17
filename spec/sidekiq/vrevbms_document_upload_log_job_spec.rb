# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VREVBMSDocumentUploadLogJob, type: :job do
  subject(:job) { described_class.new }

  let(:created_at) { Time.zone.parse('2026-01-16 10:00:00') }
  let(:claim) { create(:veteran_readiness_employment_claim, created_at:) }

  before do
    allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).with(claim.id).and_return(claim)
  end

  describe '#perform' do
    it 'logs success when processing completes' do
      expect(Rails.logger).to receive(:info)
        .with('VREVBMSDocumentUploadLogJobSuccess',
              hash_including(
                claim_id: claim.id,
                document_id: claim.parsed_form['documentId'],
                signature_date: claim.parsed_form['signatureDate'],
                created_at: claim.created_at
              ))

      job.perform(claim.id)
    end

    context 'when an error occurs' do
      it 'logs the error and re-raises' do
        allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_raise(StandardError, 'boom')

        expect(Rails.logger).to receive(:error)
          .with('VREVBMSDocumentUploadLogJobFailure',
                hash_including(
                  claim_id: claim.id,
                  exception_class: 'StandardError',
                  exception_message: 'boom'
                ))

        expect { job.perform(claim.id) }.to raise_error(StandardError, 'boom')
      end
    end
  end

  describe 'sidekiq configuration' do
    it 'retries failures' do
      expect(described_class.sidekiq_options_hash['retry']).to eq(2)
    end

    it 'has retries_exhausted handler' do
      expect(Rails.logger).to receive(:error)
        .with("VREVBMSDocumentUploadLogJob: Claim ID #{claim.id} failed after all retries")
      expect(StatsD).to receive(:increment)
        .with('worker.vre.vbms_document_upload_log_job.retries_exhausted')

      msg = { 'args' => [claim.id] }
      described_class.sidekiq_retries_exhausted_block.call(msg, StandardError.new)
    end
  end
end
