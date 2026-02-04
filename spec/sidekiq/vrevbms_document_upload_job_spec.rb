# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VREVBMSDocumentUploadJob, type: :job do
  subject(:job) { described_class.new }

  let(:created_at) { Time.zone.parse('2026-01-16 10:00:00') }
  let(:claim) { create(:veteran_readiness_employment_claim, created_at:) }

  before do
    allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).with(claim.id).and_return(claim)
    allow(claim).to receive(:upload_to_vbms)
  end

  describe '#perform' do
    it "sets signatureDate to the claim's creation date" do
      job.perform(claim.id)

      signature_date = claim.reload.parsed_form['signatureDate']
      expect(Date.parse(signature_date.to_s)).to eq(created_at.to_date)
    end

    it 'calls upload_to_vbms with the user_account uuid' do
      user_account = create(:user_account)
      allow(claim).to receive(:user_account).and_return(user_account)

      expect(claim).to receive(:upload_to_vbms) do |args|
        expect(args[:user].uuid).to eq(user_account.id)
      end

      job.perform(claim.id)
    end

    it 'handles missing user_account gracefully' do
      allow(claim).to receive(:user_account).and_return(nil)

      expect(claim).to receive(:upload_to_vbms) do |args|
        expect(args[:user].uuid).to eq('manual-run-missing-user-account')
      end

      expect { job.perform(claim.id) }.not_to raise_error
    end

    it 'logs success when processing completes' do
      new_document_id = 'new-doc-id-123'
      allow(claim).to receive(:upload_to_vbms) do
        claim.parsed_form['documentId'] = new_document_id
        claim.save!
      end

      expect(Rails.logger).to receive(:info)
        .with('VRE_VBMS_BACKFILL_SUCCESS',
              hash_including(
                claim_id: claim.id,
                old_vbms_document_id: anything,
                new_vbms_document_id: new_document_id
              ))

      job.perform(claim.id)
    end

    context 'when an error occurs' do
      it 'logs the error and re-raises' do
        allow(claim).to receive(:upload_to_vbms).and_raise(StandardError, 'boom')

        expect(Rails.logger).to receive(:error)
          .with('VRE_VBMS_BACKFILL_FAILURE',
                hash_including(
                  claim_id: claim.id,
                  old_vbms_document_id: anything,
                  exception_class: 'StandardError',
                  exception_message: 'boom'
                ))

        expect { job.perform(claim.id) }.to raise_error(StandardError, 'boom')
      end
    end
  end

  describe 'sidekiq configuration' do
    it 'retries failures' do
      expect(described_class.sidekiq_options_hash['retry']).to eq(16)
    end

    it 'has retries_exhausted handler' do
      # Test by triggering the actual callback mechanism
      expect(Rails.logger).to receive(:error)
        .with("VRE_VBMS_BACKFILL_RETRIES_EXHAUSTED: Claim ID #{claim.id} failed after all retries")
      expect(StatsD).to receive(:increment)
        .with('worker.vre.vbms_document_upload_job.retries_exhausted')

      msg = { 'args' => [claim.id] }
      described_class.sidekiq_retries_exhausted_block.call(msg, StandardError.new)
    end
  end
end
