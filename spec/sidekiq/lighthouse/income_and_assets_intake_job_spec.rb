# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/service'
require 'central_mail/datestamp_pdf'

RSpec.describe Lighthouse::IncomeAndAssetsIntakeJob, :uploader_helpers do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:income_and_assets_claim) }
  let(:service) { double('service') }
  let(:monitor) { double('monitor') }
  let(:user_account_uuid) { 123 }

  describe '#perform' do
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }

    before do
      job.instance_variable_set(:@claim, claim)
      allow(SavedClaim::IncomeAndAssets).to receive(:find).and_return(claim)
      allow(claim).to receive_messages(to_pdf: pdf_path, persistent_attachments: [])

      job.instance_variable_set(:@intake_service, service)
      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:request_upload)
      allow(service).to receive_messages(location:, perform_upload: response)
      allow(response).to receive(:success?).and_return true

      job.instance_variable_set(:@ia_monitor, monitor)
      allow(monitor).to receive :track_submission_begun
      allow(monitor).to receive :track_submission_attempted
      allow(monitor).to receive :track_submission_success
      allow(monitor).to receive :track_submission_retry
    end

    it 'submits the saved claim successfully' do
      allow(job).to receive(:process_document).and_return(pdf_path)

      expect(FormSubmission).to receive(:create)
      expect(FormSubmissionAttempt).to receive(:create)
      expect(Datadog::Tracing).to receive(:active_trace)
      expect(UserAccount).to receive(:find)

      expect(service).to receive(:perform_upload).with(
        upload_url: 'test_location', document: pdf_path, metadata: anything, attachments: []
      )
      expect(job).to receive(:cleanup_file_paths)

      job.perform(claim.id, :user_account_uuid)
    end

    it 'is unable to find user_account' do
      expect(SavedClaim::IncomeAndAssets).not_to receive(:find)
      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        ActiveRecord::RecordNotFound,
        "Couldn't find UserAccount with 'id'=user_account_uuid"
      )
    end

    it 'is unable to find saved_claim_id' do
      allow(SavedClaim::IncomeAndAssets).to receive(:find).and_return(nil)

      expect(UserAccount).to receive(:find)

      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        Lighthouse::IncomeAndAssetsIntakeJob::IncomeAndAssetsIntakeError,
        "Unable to find SavedClaim::IncomeAndAssets #{claim.id}"
      )
    end

    # perform
  end

  describe '#process_document' do
    let(:service) { double('service') }
    let(:pdf_path) { 'random/path/to/pdf' }

    before do
      job.instance_variable_set(:@intake_service, service)
    end

    it 'returns a datestamp pdf path' do
      run_count = 0
      allow_any_instance_of(CentralMail::DatestampPdf).to receive(:run) {
                                                            run_count += 1
                                                            pdf_path
                                                          }
      allow(service).to receive(:valid_document?).and_return(pdf_path)
      new_path = job.send(:process_document, 'test/path')

      expect(new_path).to eq(pdf_path)
      expect(run_count).to eq(2)
    end
    # process_document
  end

  describe '#cleanup_file_paths' do
    before do
      job.instance_variable_set(:@form_path, 'path/file.pdf')
      job.instance_variable_set(:@attachment_paths, '/invalid_path/should_be_an_array.failure')

      job.instance_variable_set(:@ia_monitor, monitor)
      allow(monitor).to receive(:track_file_cleanup_error)
    end

    it 'returns expected hash' do
      expect(monitor).to receive(:track_file_cleanup_error)
      expect { job.send(:cleanup_file_paths) }.to raise_error(
        Lighthouse::IncomeAndAssetsIntakeJob::IncomeAndAssetsIntakeError,
        anything
      )
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    context 'when retries are exhausted' do
      it 'logs a distrinct error when no claim_id provided' do
        Lighthouse::IncomeAndAssetsIntakeJob.within_sidekiq_retries_exhausted_block do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::IncomeAndAssetsIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: nil, user_account_uuid: nil, claim_id: nil)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.income_and_assets_intake_job.exhausted')
        end
      end

      it 'logs a distrinct error when only claim_id provided' do
        Lighthouse::IncomeAndAssetsIntakeJob.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::IncomeAndAssetsIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: claim.confirmation_number,
                                     user_account_uuid: nil, claim_id: claim.id)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.income_and_assets_intake_job.exhausted')
        end
      end

      it 'logs a distrinct error when claim_id and user_account_uuid provided' do
        Lighthouse::IncomeAndAssetsIntakeJob.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, 2] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::IncomeAndAssetsIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: claim.confirmation_number, user_account_uuid: 2,
                                     claim_id: claim.id)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.income_and_assets_intake_job.exhausted')
        end
      end

      it 'logs a distrinct error when claim is not found' do
        Lighthouse::IncomeAndAssetsIntakeJob.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1, 2] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::IncomeAndAssetsIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: nil, user_account_uuid: 2, claim_id: claim.id - 1)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.income_and_assets_intake_job.exhausted')
        end
      end
    end
  end

  # Rspec.describe
end
