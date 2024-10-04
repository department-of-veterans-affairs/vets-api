# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'

RSpec.describe Pensions::PensionBenefitIntakeJob, :uploader_helpers do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:pensions_module_pension_claim) }
  let(:service) { double('service') }
  let(:monitor) { double('monitor') }
  let(:user_account_uuid) { 123 }

  describe '#perform' do
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }

    before do
      job.instance_variable_set(:@claim, claim)
      allow(Pensions::SavedClaim).to receive(:find).and_return(claim)
      allow(claim).to receive_messages(to_pdf: pdf_path, persistent_attachments: [])

      job.instance_variable_set(:@intake_service, service)
      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:request_upload)
      allow(service).to receive_messages(location:, perform_upload: response)
      allow(response).to receive(:success?).and_return true

      job.instance_variable_set(:@pension_monitor, monitor)
      allow(monitor).to receive :track_submission_begun
      allow(monitor).to receive :track_submission_attempted
      allow(monitor).to receive :track_submission_success
      allow(monitor).to receive :track_submission_retry
    end

    it 'submits the saved claim successfully' do
      allow(job).to receive_messages(process_document: pdf_path, form_submission_pending_or_success: false)

      expect(FormSubmission).to receive(:create)
      expect(FormSubmissionAttempt).to receive(:create)
      expect(Datadog::Tracing).to receive(:active_trace)
      expect(UserAccount).to receive(:find)

      expect(service).to receive(:perform_upload).with(
        upload_url: 'test_location', document: pdf_path, metadata: anything, attachments: []
      )
      expect(job).to receive(:cleanup_file_paths)

      job.perform(claim.id, :user_uuid)
    end

    it 'is unable to find user_account' do
      expect(Pensions::SavedClaim).not_to receive(:find)
      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        ActiveRecord::RecordNotFound,
        "Couldn't find UserAccount with 'id'=user_account_uuid"
      )
    end

    it 'is unable to find saved_claim_id' do
      allow(Pensions::SavedClaim).to receive(:find).and_return(nil)

      expect(UserAccount).to receive(:find)

      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        Pensions::PensionBenefitIntakeJob::PensionBenefitIntakeError,
        "Unable to find SavedClaim::Pension #{claim.id}"
      )
    end

    # perform
  end

  describe '#form_submission_pending_or_success' do
    before do
      job.instance_variable_set(:@claim, claim)
      allow(Pensions::SavedClaim).to receive(:find).and_return(claim)
    end

    context 'with no form submissions' do
      it 'returns false' do
        expect(job.send(:form_submission_pending_or_success)).to eq(false).or be_nil
      end
    end

    context 'with pending form submission attempt' do
      let(:claim) { create(:pensions_module_pension_claim, :pending) }

      it 'return true' do
        expect(job.send(:form_submission_pending_or_success)).to eq(true)
      end
    end

    context 'with success form submission attempt' do
      let(:claim) { create(:pensions_module_pension_claim, :success) }

      it 'return true' do
        expect(job.send(:form_submission_pending_or_success)).to eq(true)
      end
    end

    context 'with failure form submission attempt' do
      let(:claim) { create(:pensions_module_pension_claim, :failure) }

      it 'return false' do
        expect(job.send(:form_submission_pending_or_success)).to eq(false)
      end
    end
  end

  describe '#process_document' do
    let(:service) { double('service') }
    let(:pdf_path) { 'random/path/to/pdf' }

    before do
      job.instance_variable_set(:@intake_service, service)
    end

    it 'returns a datestamp pdf path' do
      run_count = 0
      allow_any_instance_of(PDFUtilities::DatestampPdf).to receive(:run) {
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

      job.instance_variable_set(:@pension_monitor, monitor)
      allow(monitor).to receive(:track_file_cleanup_error)
    end

    it 'errors and logs but does not reraise' do
      expect(monitor).to receive(:track_file_cleanup_error)
      job.send(:cleanup_file_paths)
    end
  end

  describe '#send_confirmation_email' do
    let(:monitor_error) { create(:monitor_error) }

    before do
      job.instance_variable_set(:@claim, claim)
      allow(claim).to receive(:send_confirmation_email).and_raise(monitor_error)

      job.instance_variable_set(:@pension_monitor, monitor)
      allow(monitor).to receive(:track_send_confirmation_email_failure)
    end

    it 'errors and logs but does not reraise' do
      expect(monitor).to receive(:track_send_confirmation_email_failure)
      job.send(:send_confirmation_email)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    context 'when retries are exhausted' do
      it 'logs a distinct error when no claim_id provided' do
        Pensions::PensionBenefitIntakeJob.within_sidekiq_retries_exhausted_block do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: nil, user_uuid: nil, claim_id: nil)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
        end
      end

      it 'logs a distinct error when only claim_id provided' do
        Pensions::PensionBenefitIntakeJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: claim.confirmation_number,
                                     user_uuid: nil, claim_id: claim.id)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
        end
      end

      it 'logs a distinct error when claim_id and user_uuid provided' do
        Pensions::PensionBenefitIntakeJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, 2] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: claim.confirmation_number, user_uuid: 2, claim_id: claim.id)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
        end
      end

      it 'logs a distinct error when claim is not found' do
        Pensions::PensionBenefitIntakeJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1, 2] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: nil, user_uuid: 2, claim_id: claim.id - 1)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
        end
      end
    end
  end

  # Rspec.describe
end
