# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::BenefitsIntake::Submit10278Job do
  let(:job) { described_class.new }
  let(:claim) { create(:va10278) }
  let(:service) { instance_double(BenefitsIntake::Service) }
  let(:user_account_uuid) { SecureRandom.uuid }

  let(:parsed_form_with_claimant) do
    {
      'claimantPersonalInformation' => {
        'fullName' => {
          'first' => 'John',
          'last' => 'Doe'
        },
        'ssn' => '123456789',
        'vaFileNumber' => '987654321'
      },
      'claimantAddress' => {
        'zipCode' => '12345'
      }
    }
  end

  describe '#perform' do
    let(:response) { instance_double(Faraday::Response, success?: true) }
    let(:pdf_path) { 'tmp/pdfs/22-10278_test.pdf' }
    let(:location) { 'https://test-location.com/upload' }
    let(:benefits_intake_uuid) { SecureRandom.uuid }

    before do
      allow(SavedClaim::EducationBenefits::VA10278).to receive(:find).and_return(claim)
      allow(claim).to receive_messages(to_pdf: pdf_path, parsed_form: parsed_form_with_claimant, business_line: 'EDU')

      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
      allow(service).to receive(:request_upload)
      allow(service).to receive_messages(uuid: benefits_intake_uuid, location:, perform_upload: response)

      allow(Common::FileHelpers).to receive(:delete_file_if_exists)
      allow(Datadog::Tracing).to receive(:active_trace).and_return(double(set_tag: true))
    end

    context 'when submission is successful' do
      before do
        allow(claim).to receive(:lighthouse_submissions).and_return([])
      end

      it 'submits the claim to Benefits Intake successfully' do
        expect(service).to receive(:request_upload)
        expect(Lighthouse::Submission).to receive(:create!).and_call_original
        expect(Lighthouse::SubmissionAttempt).to receive(:create!).and_call_original
        expect(service).to receive(:perform_upload).with(
          upload_url: location,
          document: pdf_path,
          metadata: anything
        ).and_return(response)

        result = job.perform(claim.id, user_account_uuid)
        expect(result).to eq(benefits_intake_uuid)
      end

      it 'creates Lighthouse::Submission and SubmissionAttempt records' do
        expect { job.perform(claim.id, user_account_uuid) }
          .to change(Lighthouse::Submission, :count).by(1)
          .and change(Lighthouse::SubmissionAttempt, :count).by(1)
      end

      it 'increments the success StatsD counter' do
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('worker.education_form.benefits_intake.submit_10278.success')
        job.perform(claim.id, user_account_uuid)
      end

      it 'cleans up the PDF file' do
        expect(Common::FileHelpers).to receive(:delete_file_if_exists).with(pdf_path)
        job.perform(claim.id, user_account_uuid)
      end
    end

    context 'when a pending/successful submission already exists' do
      let(:lighthouse_submission) { create(:lighthouse_submission, saved_claim: claim) }

      before do
        create(:lighthouse_submission_attempt, :pending, submission: lighthouse_submission)
        allow(claim).to receive(:lighthouse_submissions).and_return([lighthouse_submission])
      end

      it 'returns early and does not submit again' do
        expect(service).not_to receive(:request_upload)
        expect(service).not_to receive(:perform_upload)
        job.perform(claim.id, user_account_uuid)
      end
    end

    context 'when claim is not found' do
      before do
        allow(SavedClaim::EducationBenefits::VA10278).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      end

      it 'raises an error' do
        expect { job.perform(claim.id, user_account_uuid) }
          .to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when upload fails' do
      let(:failed_response) { instance_double(Faraday::Response, success?: false, to_s: 'Upload failed') }

      before do
        allow(claim).to receive(:lighthouse_submissions).and_return([])
        allow(service).to receive(:perform_upload).and_return(failed_response)
      end

      it 'raises an error and increments failure counter' do
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('worker.education_form.benefits_intake.submit_10278.failure')
        expect { job.perform(claim.id, user_account_uuid) }
          .to raise_error(EducationForm::BenefitsIntake::Submit10278Job::Submit10278JobError)
      end

      it 'marks the submission attempt as failed' do
        submission_attempt = nil
        allow(Lighthouse::SubmissionAttempt).to receive(:create!) do |**args|
          submission_attempt = Lighthouse::SubmissionAttempt.new(**args)
          allow(submission_attempt).to receive(:fail!)
          submission_attempt
        end

        expect { job.perform(claim.id, user_account_uuid) }.to raise_error(
          EducationForm::BenefitsIntake::Submit10278Job::Submit10278JobError
        )
        expect(submission_attempt).to have_received(:fail!)
      end
    end
  end

  describe '#generate_metadata' do
    before do
      job.instance_variable_set(:@claim, claim)
      allow(claim).to receive_messages(parsed_form: parsed_form_with_claimant, business_line: 'EDU')
    end

    it 'generates metadata with claimant information' do
      metadata = job.send(:generate_metadata)

      expect(metadata['veteranFirstName']).to eq('John')
      expect(metadata['veteranLastName']).to eq('Doe')
      expect(metadata['fileNumber']).to eq('987654321')
      expect(metadata['zipCode']).to eq('12345')
      expect(metadata['docType']).to eq('22-10278')
      expect(metadata['businessLine']).to eq('EDU')
    end

    context 'when vaFileNumber is not present' do
      let(:parsed_form_without_va_file_number) do
        {
          'claimantPersonalInformation' => {
            'fullName' => { 'first' => 'John', 'last' => 'Doe' },
            'ssn' => '123456789'
          },
          'claimantAddress' => { 'zipCode' => '12345' }
        }
      end

      before do
        allow(claim).to receive(:parsed_form).and_return(parsed_form_without_va_file_number)
      end

      it 'uses SSN as file number' do
        metadata = job.send(:generate_metadata)
        expect(metadata['fileNumber']).to eq('123456789')
      end
    end

    context 'when postalCode is used instead of zipCode' do
      let(:parsed_form_with_postal_code) do
        {
          'claimantPersonalInformation' => {
            'fullName' => { 'first' => 'John', 'last' => 'Doe' },
            'ssn' => '123456789'
          },
          'claimantAddress' => { 'postalCode' => '54321' }
        }
      end

      before do
        allow(claim).to receive(:parsed_form).and_return(parsed_form_with_postal_code)
      end

      it 'uses postalCode for zip' do
        metadata = job.send(:generate_metadata)
        expect(metadata['zipCode']).to eq('54321')
      end
    end
  end

  describe '#lighthouse_submission_pending_or_success?' do
    before do
      job.instance_variable_set(:@claim, claim)
    end

    context 'with no lighthouse submissions' do
      before do
        allow(claim).to receive(:lighthouse_submissions).and_return([])
      end

      it 'returns false' do
        expect(job.send(:lighthouse_submission_pending_or_success?)).to be(false)
      end
    end

    context 'with pending lighthouse submission attempt' do
      let(:lighthouse_submission) { create(:lighthouse_submission, saved_claim: claim) }

      before do
        create(:lighthouse_submission_attempt, :pending, submission: lighthouse_submission)
        allow(claim).to receive(:lighthouse_submissions).and_return([lighthouse_submission])
      end

      it 'returns true' do
        expect(job.send(:lighthouse_submission_pending_or_success?)).to be(true)
      end
    end

    context 'with submitted lighthouse submission attempt' do
      let(:lighthouse_submission) { create(:lighthouse_submission, saved_claim: claim) }

      before do
        create(:lighthouse_submission_attempt, :submitted, submission: lighthouse_submission)
        allow(claim).to receive(:lighthouse_submissions).and_return([lighthouse_submission])
      end

      it 'returns true' do
        expect(job.send(:lighthouse_submission_pending_or_success?)).to be(true)
      end
    end

    context 'with failed lighthouse submission attempt' do
      let(:lighthouse_submission) { create(:lighthouse_submission, saved_claim: claim) }

      before do
        create(:lighthouse_submission_attempt, :failure, submission: lighthouse_submission)
        allow(claim).to receive(:lighthouse_submissions).and_return([lighthouse_submission])
      end

      it 'returns false' do
        expect(job.send(:lighthouse_submission_pending_or_success?)).to be(false)
      end
    end
  end

  describe '#cleanup_file_paths' do
    before do
      job.instance_variable_set(:@form_path, 'tmp/pdfs/test.pdf')
      job.instance_variable_set(:@claim, claim)
    end

    it 'deletes the form PDF file' do
      expect(Common::FileHelpers).to receive(:delete_file_if_exists).with('tmp/pdfs/test.pdf')
      job.send(:cleanup_file_paths)
    end

    context 'when deletion fails' do
      before do
        allow(Common::FileHelpers).to receive(:delete_file_if_exists).and_raise(StandardError, 'File error')
      end

      it 'logs the error but does not raise' do
        expect(Rails.logger).to receive(:error)
        expect { job.send(:cleanup_file_paths) }.not_to raise_error
      end
    end
  end

  describe 'sidekiq_retries_exhausted' do
    let(:msg) do
      {
        'args' => [claim.id, user_account_uuid],
        'class' => 'EducationForm::BenefitsIntake::Submit10278Job',
        'error_message' => 'Test error'
      }
    end

    context 'when claim exists' do
      before do
        allow(SavedClaim::EducationBenefits::VA10278).to receive(:find_by).with(id: claim.id).and_return(claim)
      end

      it 'logs the exhaustion error' do
        expect(Rails.logger).to receive(:error).with(
          'EducationForm::BenefitsIntake::Submit10278Job exhausted retries for claim ' \
          "#{claim.id}",
          hash_including(:claim_id, :form_id, :confirmation_number)
        )
        expect(StatsD).to receive(:increment).with('worker.education_form.benefits_intake.submit_10278.exhausted')

        described_class.within_sidekiq_retries_exhausted_block(msg) {}
      end
    end

    context 'when claim does not exist' do
      before do
        allow(SavedClaim::EducationBenefits::VA10278).to receive(:find_by).with(id: claim.id).and_return(nil)
      end

      it 'logs that claim was not found' do
        expect(Rails.logger).to receive(:error).with(
          'EducationForm::BenefitsIntake::Submit10278Job exhausted retries - claim not found',
          hash_including(:claim_id, :form_id)
        )

        described_class.within_sidekiq_retries_exhausted_block(msg) {}
      end
    end
  end
end
