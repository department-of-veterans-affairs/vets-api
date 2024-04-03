# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::PensionBenefitIntakeJob, uploader_helpers: true do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:pension_claim) }

  describe '#perform' do
    let(:service) { double('service') }
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }
    let(:user_uuid) { 123 }

    before do
      allow(job).to receive(:process_pdf).and_return(pdf_path)

      allow(SavedClaim::Pension).to receive(:find).and_return(claim)
      allow(claim).to receive(:to_pdf).and_return(pdf_path)

      allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:location).and_return(location)
      allow(service).to receive(:upload_doc).and_return(response)
    end

    context 'user id is not nil' do
      it 'submits the saved claim successfully' do
        doc = { file: pdf_path, file_name: 'pdf' }

        expect(claim).to receive(:to_pdf)
        expect(job).to receive(:form_submission_polling)
        expect(job).to receive(:process_pdf).with(pdf_path)
        expect(job).to receive(:generate_form_metadata_lh).once
        expect(service).to receive(:upload_doc).with(
          upload_url: 'test_location', file: doc, metadata: anything, attachments: []
        )
        expect(job).to receive(:check_success).with(response)

        expect(job).to receive(:cleanup_file_paths)

        job.perform(claim.id, :user_uuid)
      end

      it 'is unable to find saved_claim_id' do
        allow(SavedClaim::Pension).to receive(:find).and_return(nil)

        expect(claim).not_to receive(:to_pdf)
        expect { job.perform(claim.id, :user_uuid) }.to raise_error(
          Lighthouse::PensionBenefitIntakeJob::PensionBenefitIntakeError,
          "Unable to find SavedClaim::Pension #{claim.id}"
        )
      end
    end

    context 'user id is nil' do
      it 'submits the saved claim successfully' do
        doc = { file: pdf_path, file_name: 'pdf' }

        expect(claim).to receive(:to_pdf)
        expect(job).to receive(:form_submission_polling)
        expect(job).to receive(:process_pdf).with(pdf_path)
        expect(job).to receive(:generate_form_metadata_lh).once
        expect(service).to receive(:upload_doc).with(
          upload_url: 'test_location', file: doc, metadata: anything, attachments: []
        )
        expect(job).to receive(:check_success).with(response)

        expect(job).to receive(:cleanup_file_paths)

        job.perform(claim.id, nil)
      end

      it 'is unable to find saved_claim_id' do
        allow(SavedClaim::Pension).to receive(:find).and_return(nil)

        expect(claim).not_to receive(:to_pdf)
        expect { job.perform(claim.id, nil) }.to raise_error(
          Lighthouse::PensionBenefitIntakeJob::PensionBenefitIntakeError,
          "Unable to find SavedClaim::Pension #{claim.id}"
        )
      end
    end
    # perform
  end

  describe '#process_pdf' do
    let(:service) { double('service') }
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }

    before do
      allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
      allow(service).to receive(:validate_document).and_return(response)
    end

    it 'returns a datestamp pdf path' do
      run_count = 0
      allow_any_instance_of(CentralMail::DatestampPdf).to receive(:run) {
                                                            run_count += 1
                                                            pdf_path
                                                          }
      allow(response).to receive(:success?).and_return(true)

      new_path = job.process_pdf('test/path')

      expect(new_path).to eq(pdf_path)
      expect(run_count).to eq(2)
    end

    it 'raises an error on invalid document' do
      allow_any_instance_of(CentralMail::DatestampPdf).to receive(:run)
      allow(response).to receive(:success?).and_return(false)

      expect { job.process_pdf('test/path') }.to raise_error(
        Lighthouse::PensionBenefitIntakeJob::PensionBenefitIntakeError,
        "Invalid Document: #{response}"
      )
    end
    # process_pdf
  end

  describe '#generate_form_metadata_lh' do
    before do
      job.instance_variable_set(:@claim, claim)
    end

    it 'returns expected hash' do
      expect(job.generate_form_metadata_lh).to include(
        'veteranFirstName' => be_a(String),
        'veteranLastName' => be_a(String),
        'fileNumber' => be_a(String),
        'zipCode' => be_a(String),
        'docType' => be_a(String),
        'businessLine' => eq(described_class::PENSION_BUSINESSLINE),
        'source' => eq(described_class::PENSION_SOURCE)
      )
    end
    # generate_form_metadata_lh
  end

  describe '#check_success' do
    let(:service) { double('service') }
    let(:response) { double('response') }

    before do
      job.instance_variable_set(:@claim, claim)
      job.instance_variable_set(:@lighthouse_service, service)
      allow(service).to receive(:uuid)
    end

    it 'sends a confirmation email on success' do
      allow(response).to receive(:success?).and_return(true)

      expect(claim).to receive(:send_confirmation_email)
      job.check_success(response)
    end

    it 'does not send an email on failure' do
      allow(response).to receive(:message).and_return('TEST RESPONSE')
      allow(response).to receive(:success?).and_return(false)

      expect(claim).not_to receive(:send_confirmation_email)
      expect { job.check_success(response) }.to raise_error(
        Lighthouse::PensionBenefitIntakeJob::PensionBenefitIntakeError,
        response.to_s
      )
    end
    # check_success
  end

  describe '#form_submission_polling' do
    let(:service) { double('service') }

    before do
      job.instance_variable_set(:@claim, claim)
      job.instance_variable_set(:@lighthouse_service, service)
      allow(service).to receive(:uuid).and_return('UUID')

      allow(FormSubmission).to receive(:create)
      allow(FormSubmissionAttempt).to receive(:create)
      allow(Datadog::Tracing).to receive(:active_trace)
    end

    it 'creates polling entries' do
      form_submission = { test: 'submission' }
      expect(FormSubmission).to receive(:create).with(
        form_type: claim.form_id,
        form_data: claim.to_json,
        benefits_intake_uuid: service.uuid,
        saved_claim: claim,
        saved_claim_id: claim.id
      ).and_return(form_submission)
      expect(FormSubmissionAttempt).to receive(:create).with(form_submission:)
      expect(Datadog::Tracing).to receive(:active_trace)

      job.form_submission_polling
    end
    # form_submission_polling
  end

  describe 'sidekiq_retries_exhausted block' do
    context 'when retries are exhausted' do
      it 'logs a distrinct error when no claim_id provided' do
        Lighthouse::PensionBenefitIntakeJob.within_sidekiq_retries_exhausted_block do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: nil, user_uuid: nil, claim_id: nil)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
        end
      end

      it 'logs a distrinct error when only claim_id provided' do
        Lighthouse::PensionBenefitIntakeJob.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: claim.confirmation_number,
                                     user_uuid: nil, claim_id: claim.id)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
        end
      end

      it 'logs a distrinct error when claim_id and user_uuid provided' do
        Lighthouse::PensionBenefitIntakeJob.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, 2] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: claim.confirmation_number, user_uuid: 2, claim_id: claim.id)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
        end
      end

      it 'logs a distrinct error when claim is not found' do
        Lighthouse::PensionBenefitIntakeJob.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1, 2] }) do
          expect(Rails.logger).to receive(:error).exactly(:once).with(
            'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
            hash_including(:message, confirmation_number: nil, user_uuid: 2, claim_id: claim.id - 1)
          )
          expect(StatsD).to receive(:increment).with('worker.lighthouse.pension_benefit_intake_job.exhausted')
        end
      end
    end
  end

  describe '#cleanup_file_paths' do
    before do
      job.instance_variable_set(:@form_path, 'path/file.pdf')
      job.instance_variable_set(:@attachment_paths, '/invalid_path/should_be_an_array.failure')
    end

    it 'returns expected hash' do
      expect(Rails.logger).to receive(:error).with('Lighthouse::PensionBenefitIntakeJob cleanup failed',
                                                   hash_including(:error, :claim_id, :confirmation_number,
                                                                  :benefits_intake_uuid))
      expect { job.cleanup_file_paths }.to raise_error(NoMethodError)
    end
  end

  # Rspec.describe
end
