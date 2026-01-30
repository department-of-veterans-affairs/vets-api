# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/service'
require 'increase_compensation/benefits_intake/submit_claim_job'
require 'increase_compensation/monitor'
require 'pdf_utilities/datestamp_pdf'

RSpec.describe IncreaseCompensation::BenefitsIntake::SubmitClaimJob, :uploader_helpers do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:increase_compensation_claim) }
  let(:service) { double('service') }
  let(:monitor) { IncreaseCompensation::Monitor.new }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { 123 }

  describe '#perform' do
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }
    let(:omit_esign_stamp) { true }
    let(:extras_redesign) { true }

    before do
      job.instance_variable_set(:@claim, claim)
      allow(IncreaseCompensation::SavedClaim).to receive(:find).and_return(claim)
      allow(claim).to receive(:to_pdf).with(claim.id, { extras_redesign:, omit_esign_stamp: }).and_return(pdf_path)
      allow(claim).to receive(:persistent_attachments).and_return([])

      job.instance_variable_set(:@intake_service, service)
      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:request_upload)
      allow(service).to receive_messages(location:, perform_upload: response)
      allow(response).to receive(:success?).and_return true

      job.instance_variable_set(:@monitor, monitor)
    end

    context 'with increase_compensation_form_enabled flipper' do
      # before do
      #   allow(UserAccount).to receive(:find).and_return(instance_double(user_account))
      # end

      it 'processes claim when flipper is enabled' do
        allow(Flipper).to receive(:enabled?).with(:increase_compensation_form_enabled).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:increase_compensation_govcio_mms).and_return(false)
        allow(job).to receive(:process_document).and_return(pdf_path)
        allow(UserAccount).to receive(:find).and_return(user_account)

        expect(IncreaseCompensation::SavedClaim).to receive(:find).and_return(claim)
        expect(claim).to receive(:to_pdf)
        expect(service).to receive(:perform_upload)
        expect(job).to receive(:cleanup_file_paths)

        result = job.perform(claim.id, user_account_uuid)
        expect(result).to eq(service.uuid)
      end

      it 'returns early when flipper is disabled' do
        allow(Flipper).to receive(:enabled?).with(:increase_compensation_form_enabled).and_return(false)

        expect(IncreaseCompensation::SavedClaim).not_to receive(:find)
        expect(claim).not_to receive(:to_pdf)
        expect(service).not_to receive(:perform_upload)

        result = job.perform(claim.id, user_account_uuid)
        expect(result).to be_nil
      end
    end

    it 'submits the saved claim successfully' do
      allow(job).to receive(:process_document).and_return(pdf_path)
      allow(Flipper).to receive(:enabled?).with(:increase_compensation_govcio_mms).and_return(false)

      expect(claim).to receive(:to_pdf).with(claim.id, { extras_redesign:, omit_esign_stamp: }).and_return(pdf_path)
      expect(Lighthouse::Submission).to receive(:create)
      expect(Lighthouse::SubmissionAttempt).to receive(:create)
      expect(Datadog::Tracing).to receive(:active_trace)
      expect(UserAccount).to receive(:find)

      expect(service).to receive(:perform_upload).with(
        upload_url: 'test_location', document: pdf_path, metadata: anything, attachments: []
      )
      expect(job).to receive(:cleanup_file_paths)

      job.perform(claim.id, :user_account_uuid)
    end

    it 'is unable to find user_account' do
      expect(IncreaseCompensation::SavedClaim).not_to receive(:find)
      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        ActiveRecord::RecordNotFound,
        /Couldn't find UserAccount/
      )
    end

    it 'is unable to find saved_claim_id' do
      allow(IncreaseCompensation::SavedClaim).to receive(:find).and_return(nil)

      expect(UserAccount).to receive(:find)

      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        IncreaseCompensation::BenefitsIntake::SubmitClaimJob::IncreaseCompensationBenefitIntakeError,
        "Unable to find IncreaseCompensation::SavedClaim #{claim.id}"
      )
    end
    # perform
  end

  describe '#govcio_upload' do
    let(:ibm_service) { double('ibm_service') }
    let(:response) { double('response') }

    before do
      claim.guid = 'test_guid'
      job.instance_variable_set(:@intake_service, service)
      job.instance_variable_set(:@claim, claim)
      allow(service).to receive(:uuid).and_return('test_guid')

      job.instance_variable_set(:@ibm_payload, { test: 'data' })

      allow(Ibm::Service).to receive(:new).and_return(ibm_service)
      allow(ibm_service).to receive(:upload_form).and_return(response)
      allow(response).to receive(:success?).and_return(true)
    end

    it 'uploads to IBM MMS when govcio flipper is enabled' do
      allow(Flipper).to receive(:enabled?).with(:increase_compensation_govcio_mms).and_return(true)

      expect(Ibm::Service).to receive(:new)
      expect(ibm_service).to receive(:upload_form).with(form: { test: 'data' }.to_json, guid: 'test_guid')

      job.send(:govcio_upload)
    end

    it 'does not upload to IBM MMS when govcio flipper is disabled' do
      allow(Flipper).to receive(:enabled?).with(:increase_compensation_govcio_mms).and_return(false)

      expect(Ibm::Service).not_to receive(:new)
      expect(ibm_service).not_to receive(:upload_form)

      job.send(:govcio_upload)
    end
  end

  describe '#process_document' do
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:datestamp_pdf_double) { instance_double(PDFUtilities::DatestampPdf) }

    before do
      job.instance_variable_set(:@intake_service, service)
      job.instance_variable_set(:@claim, claim)
    end

    it 'returns a datestamp pdf path' do
      run_count = 0
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_pdf_double)
      allow(datestamp_pdf_double).to receive(:run) {
        run_count += 1
        pdf_path
      }
      allow(service).to receive(:valid_document?).and_return(pdf_path)
      allow(File).to receive(:exist?).with(pdf_path).and_return(true)
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

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_file_cleanup_error)
    end

    it 'errors and logs but does not reraise' do
      expect(monitor).to receive(:track_file_cleanup_error)
      job.send(:cleanup_file_paths)
    end
  end

  describe '#send_submitted_email' do
    let(:monitor_error) { create(:monitor_error) }
    let(:notification) { double('notification') }

    before do
      job.instance_variable_set(:@claim, claim)

      allow(IncreaseCompensation::NotificationEmail).to receive(:new).and_return(notification)
      allow(notification).to receive(:deliver).and_raise(monitor_error)

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_send_email_failure)
    end

    it 'errors and logs but does not reraise' do
      expect(IncreaseCompensation::NotificationEmail).to receive(:new).with(claim.id)
      expect(notification).to receive(:deliver).with(:submitted)
      expect(monitor).to receive(:track_send_email_failure)
      job.send(:send_submitted_email)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    let(:exhaustion_msg) do
      { 'args' => [], 'class' => 'IncreaseCompensation::BenefitsIntake::SubmitClaimJob',
        'error_message' => 'An error occurred', 'queue' => 'low' }
    end

    before do
      allow(IncreaseCompensation::Monitor).to receive(:new).and_return(monitor)
    end

    context 'when retries are exhausted' do
      it 'logs a distrinct error when no claim_id provided' do
        IncreaseCompensation::BenefitsIntake::SubmitClaimJob.within_sidekiq_retries_exhausted_block do
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end

      it 'logs a distrinct error when only claim_id provided' do
        IncreaseCompensation::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
            allow(IncreaseCompensation::SavedClaim).to receive(:find).and_return(claim)
            expect(IncreaseCompensation::SavedClaim).to receive(:find).with(claim.id)

            exhaustion_msg['args'] = [claim.id]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distrinct error when claim_id and user_account_uuid provided' do
        IncreaseCompensation::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, 2] }) do
            allow(IncreaseCompensation::SavedClaim).to receive(:find).and_return(claim)
            expect(IncreaseCompensation::SavedClaim).to receive(:find).with(claim.id)

            exhaustion_msg['args'] = [claim.id, 2]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distrinct error when claim is not found' do
        IncreaseCompensation::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1, 2] }) do
            expect(IncreaseCompensation::SavedClaim).to receive(:find).with(claim.id - 1)

            exhaustion_msg['args'] = [claim.id - 1, 2]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end
    end
  end

  # Rspec.describe
end
