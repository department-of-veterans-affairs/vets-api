# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::PollForm526Pdf, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
      .and_return({ 'data' => { 'attributes' => { 'supportingDocuments' => [] } } })
  end

  describe '.perform_async' do
    let(:form526_submission) { create(:form526_submission, submitted_claim_id: 1) }

    context 'successful polling' do
      it 'logs success when PDF is found' do
        allow(Flipper).to receive(:enabled?).with(:disability_526_call_received_email_from_polling).and_return(true)

        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
          .and_return(
            { 'data' =>
                { 'attributes' =>
                    { 'supportingDocuments' =>
                        [{ 'documentTypeLabel' =>
                             'VA 21-526 Veterans Application for Compensation or Pension' }] } } }
          )
        expect(Rails.logger).to receive(:info).with(
          'Form526 Submission',
          hash_including(
            'job_id' => kind_of(String),
            'saved_claim_id' => kind_of(Integer),
            'service_provider' => nil,
            'status' => 'try',
            'submission_id' => form526_submission.id
          )
        )
        expect(Rails.logger).to receive(:info).with('Form526ConfirmationEmailJob called for user ' \
                                                    "#{form526_submission.account.id}, " \
                                                    "submission: #{form526_submission.id} from PollForm526Pdf#perform" \
                                                    ' pdf_found')

        expect(Rails.logger).to receive(:info).with(
          'Form526 Submission',
          hash_including(
            'job_id' => kind_of(String),
            'saved_claim_id' => kind_of(Integer),
            'service_provider' => nil,
            'status' => 'success',
            'submission_id' => form526_submission.id
          )
        )

        expect(Rails.logger).to receive(:info).with('Poll for form 526 PDF: PDF found')
        subject.perform_sync(form526_submission.id)

        form526_submission.reload

        job_status = form526_submission.form526_job_statuses.find_by(job_class: 'PollForm526Pdf')
        job_status.reload
        expect(job_status.status).to eq 'success'
      end
    end

    context 'pdf not found scenarios' do
      it 'raises an error and retries when no supporting documents are found and submission is less than 1 day old' do
        form526_submission.update!(created_at: 12.hours.ago)
        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
          .and_return({ 'data' => { 'attributes' => { 'supportingDocuments' => [] } } })

        expect do
          subject.perform_sync(form526_submission.id)
        end.to raise_error(Lighthouse::PollForm526PdfError,
                           'Poll for form 526 PDF: Keep on retrying!')
      end

      it 'transitions to pdf_not_found when submission is exactly 4 days old' do
        form526_submission.update!(created_at: 4.days.ago)
        expect(Rails.logger).to receive(:warn).with('Poll for form 526 PDF: Submission creation date is over 4 days' \
                                                    ' old. Exiting...',
                                                    hash_including(error_class: 'PollForm526PdfError'))

        subject.perform_sync(form526_submission.id)
        form526_submission.reload

        job_status = form526_submission.form526_job_statuses.find_by(job_class: 'PollForm526Pdf')
        expect(job_status.status).to eq 'pdf_not_found'
      end

      it 'transitions to pdf_not_found status if submission is older than 4 days' do
        form526_submission.update(created_at: 5.days.ago)
        expect(Rails.logger).to receive(:warn).with(
          'Poll for form 526 PDF: Submission creation date is over 4 days old. Exiting...',
          { error_class: 'PollForm526PdfError',
            error_message: 'Poll for form 526 PDF: Submission creation date is over 4 days old. Exiting...',
            form526_submission_id: form526_submission.id,
            job_id: kind_of(String),
            timestamp: kind_of(Time) }
        )
        subject.perform_sync(form526_submission.id)

        form526_submission.reload

        job_status = form526_submission.form526_job_statuses.find_by(job_class: 'PollForm526Pdf')
        job_status.reload
        expect(job_status.status).to eq 'pdf_not_found'
      end

      it 'warns if submission is between 1 and 4 days old' do
        id = form526_submission.id
        form526_submission.update!(created_at: 2.days.ago)
        expect(Rails.logger).to receive(:warn).with(
          "Poll for form 526 PDF: Submission creation date is over 1 day old for submission_id #{id}",
          { error_class: 'PollForm526PdfError',
            error_message: "Poll for form 526 PDF: Submission creation date is over 1 day old for submission_id #{id}",
            form526_submission_id: id,
            job_id: kind_of(String),
            timestamp: kind_of(Time) }
        )
        expect { subject.perform_sync(form526_submission.id) }.to raise_error(Lighthouse::PollForm526PdfError)
        form526_submission.reload
      end
    end

    context 'when all retries are exhausted' do
      let(:form526_job_status) { create(:form526_job_status, :poll_form526_pdf, form526_submission:, job_id: 1) }

      it 'transitions to the pdf_not_found status' do
        job_params = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }

        subject.within_sidekiq_retries_exhausted_block(job_params) do
          # block is required to use this functionality.
          true
        end
        form526_job_status.reload
        expect(form526_job_status.status).to eq 'pdf_not_found'
      end
    end

    context 'startedFormVersion missing' do
      it 'calls polling only for startedFormVersion present, does not retry because the form is there,
                                                                      and triggers confirmation email' do
        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
          .and_return(
            { 'data' =>
                { 'attributes' =>
                    { 'supportingDocuments' =>
                        [{ 'documentTypeLabel' =>
                             'VA 21-526 Veterans Application for Compensation or Pension' }] } } }
          )
        allow(Lighthouse::PollForm526Pdf).to receive(:perform_async).with(form526_submission.id).and_call_original

        expect(Lighthouse::PollForm526Pdf).to receive(:perform_async).with(form526_submission.id)

        form526_submission.send(:poll_form526_pdf)
        expect do
          Lighthouse::PollForm526Pdf.drain
          job_status = form526_submission.form526_job_statuses.find_by(job_class: 'PollForm526Pdf')
          job_status.reload
          expect(job_status.status).to eq 'success'
        end.not_to raise_error

        form526_submission.send(:poll_form526_pdf)
        expect do
          Lighthouse::PollForm526Pdf.drain
        end.to change(Form526ConfirmationEmailJob.jobs, :size).by(1)
      end

      it 'calls polling only for startedFormVersion present and retries' do
        allow(Lighthouse::PollForm526Pdf).to receive(:perform_async).with(form526_submission.id).and_call_original

        expect(Lighthouse::PollForm526Pdf).to receive(:perform_async).with(form526_submission.id)

        form526_submission.send(:poll_form526_pdf)

        expect do
          Lighthouse::PollForm526Pdf.drain
          job_status = form526_submission.form526_job_statuses.find_by(job_class: 'PollForm526Pdf')
          job_status.reload
          expect(job_status.status).to eq 'try'
        end.to raise_error(Lighthouse::PollForm526PdfError)
      end

      it 'does not call polling if startedFormVersion blank' do
        form = form526_submission.saved_claim.parsed_form
        form['startedFormVersion'] = nil
        form526_submission.saved_claim.update(form: form.to_json)

        expect(Lighthouse::PollForm526Pdf).not_to receive(:perform_async)

        form526_submission.send(:poll_form526_pdf)
      end
    end
  end
end
