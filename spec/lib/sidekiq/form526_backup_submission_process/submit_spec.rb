# frozen_string_literal: true

require 'rails_helper'

require 'evss/disability_compensation_auth_headers' # required to build a Form526Submission
require 'sidekiq/form526_backup_submission_process/submit'
require 'disability_compensation/factories/api_provider_factory'
require 'evss/disability_compensation_form/form4142_processor'

RSpec.describe Sidekiq::Form526BackupSubmissionProcess::Submit, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:form526_send_backup_submission_exhaustion_email_notice).and_return(false)
    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token)
      .and_return('access_token')

    fixture_pdf = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').to_s

    converter = instance_double(
      BenefitsIntakeService::Utilities::ConvertToPdf,
      converted_filename: fixture_pdf
    )

    allow(BenefitsIntakeService::Utilities::ConvertToPdf)
      .to receive(:new)
      .and_return(converter)
  end

  let(:user) { create(:user, :loa3, :legacy_icn) }
  let(:user_account) { user.user_account }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  describe '.perform_async, disabled' do
    # Make sure it doesnt do anything if flipper disabled
    before do
      allow(Settings.form526_backup).to receive(:enabled).and_return(false)
    end

    let!(:submission) { create(:form526_submission, :with_everything, user_account:) }

    it 'creates a submission job' do
      expect { subject.perform_async(submission.id) }.to change(subject.jobs, :size).by(1)
    end

    it 'does not create an additional Form526JobStatus record (meaning it returned right away)' do
      expect { subject.perform_async(submission.id) }.not_to change(Form526JobStatus.all.count, :size)
    end
  end

  describe 'failures' do
    let(:timestamp) { Time.now.utc }

    context 'when all retries are exhausted' do
      let!(:form526_submission) { create(:form526_submission, user_account:) }
      let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 1) }

      it 'updates a StatsD counter and updates the status on an exhaustion event' do
        allow(Form526SubmissionFailureEmailJob).to receive(:perform_async).and_return(nil)
        args = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }
        subject.within_sidekiq_retries_exhausted_block(args) do
          expect(StatsD).to receive(:increment).with("#{subject::STATSD_KEY_PREFIX}.exhausted")
          expect(Rails).to receive(:logger).and_call_original
        end
        form526_job_status.reload
        expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
      end

      context 'when form526_send_backup_submission_exhaustion_email_notice is enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
                        .with(:form526_send_backup_submission_exhaustion_email_notice).and_return(true)
        end

        it 'remediates the submission via an email notification' do
          Timecop.freeze(timestamp) do
            args = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }
            subject.within_sidekiq_retries_exhausted_block(args) do
              expect(Form526SubmissionFailureEmailJob)
                .to receive(:perform_async).with(form526_submission.id, timestamp.to_s)
            end
          end
        end
      end

      context 'when form526_send_backup_submission_exhaustion_email_notice is disabled' do
        before do
          Flipper.disable(:form526_send_backup_submission_exhaustion_email_notice) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end

        it 'does not remediates the submission via an email notification' do
          Timecop.freeze(timestamp) do
            args = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }
            subject.within_sidekiq_retries_exhausted_block(args) do
              expect(Form526SubmissionFailureEmailJob)
                .not_to receive(:perform_async)
                .with(form526_submission.id, timestamp.to_s)
            end
          end
        end
      end

      context 'when the exhaustion hook fails' do
        it 'updates a StatsD counter for the silent failure' do
          allow(Form526JobStatus).to receive(:find_by).and_raise('nah')
          args = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }
          expect do
            subject.within_sidekiq_retries_exhausted_block(args) do
              expect(StatsD).to receive(:increment)
                .with('silent_failure', { tags: Form526SubmissionFailureEmailJob::DD_ZSF_TAGS })
            end
          end.to raise_error('nah')
        end
      end
    end
  end

  %w[single multi].each do |payload_method|
    describe ".perform_async, enabled, #{payload_method} payload" do
      before do
        allow(Settings.form526_backup).to receive_messages(submission_method: payload_method, enabled: true)
      end

      let!(:submission) { create(:form526_submission, :with_everything, user_account:) }
      let!(:upload_data) { submission.form[Form526Submission::FORM_526_UPLOADS] }

      context 'successfully' do
        before do
          upload_data.each do |ud|
            file = Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', 'application/pdf')
            sea = SupportingEvidenceAttachment.find_or_create_by(guid: ud['confirmationCode'])
            sea.set_file_data!(file)
            sea.save!
          end
        end

        it 'creates a job for submission' do
          expect { subject.perform_async(submission.id) }.to change(subject.jobs, :size).by(1)
        end

        it 'submits' do
          new_form_data = submission.saved_claim.parsed_form
          new_form_data['startedFormVersion'] = nil
          submission.saved_claim.form = new_form_data.to_json
          submission.saved_claim.save
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
            VCR.use_cassette('form526_backup/200_evss_get_pdf') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response_generate_pdf') do
                  jid = subject.perform_async(submission.id)
                  last = subject.jobs.last
                  jid_from_jobs = last['jid']
                  expect(jid).to eq(jid_from_jobs)
                  described_class.drain
                  expect(jid).not_to be_empty
                  # The Backup Submission process gathers form 526 and any ancillary forms
                  # to send to Central Mail at the same time

                  # Form 4142 Backup Submission Process
                  expect(submission.form['form4142']).not_to be_nil
                  form4142_processor = EVSS::DisabilityCompensationForm::Form4142Processor.new(
                    submission, submission.id
                  )
                  request_body = form4142_processor.request_body
                  metadata_hash = JSON.parse(request_body['metadata'])
                  form4142_received_date = metadata_hash['receiveDt'].in_time_zone('Central Time (US & Canada)')
                  expect(
                    submission.created_at.in_time_zone('Central Time (US & Canada)')
                  ).to be_within(1.second).of(form4142_received_date)

                  # Form 0781 Backup Submission Process
                  expect(submission.form['form0781']).not_to be_nil
                  # not really a way to test the dates here

                  job_status = Form526JobStatus.last
                  expect(job_status.form526_submission_id).to eq(submission.id)
                  expect(job_status.job_class).to eq('BackupSubmission')
                  expect(job_status.job_id).to eq(jid)
                  expect(job_status.status).to eq('success')
                  submission = Form526Submission.last
                  expect(submission.backup_submitted_claim_id).not_to be_nil
                  expect(submission.submit_endpoint).to eq('benefits_intake_api')
                end
              end
            end
          end
        end
      end

      context 'with a submission timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        end

        it 'raises a gateway timeout error' do
          jid = subject.perform_async(submission.id)
          expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
          job_status = Form526JobStatus.find_by(job_id: jid)
          expect(job_status.form526_submission_id).to eq(submission.id)
          expect(job_status.job_class).to eq('BackupSubmission')
          expect(job_status.job_id).to eq(jid)
          expect(job_status.status).to eq('retryable_error')
          error = job_status.bgjob_errors
          expect(error.first.last['error_class']).to eq('Common::Exceptions::GatewayTimeout')
          expect(error.first.last['error_message']).to eq('Gateway timeout')
        end
      end

      context 'with an unexpected error' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
        end

        it 'raises a standard error' do
          jid = subject.perform_async(submission.id)
          expect { described_class.drain }.to raise_error(StandardError)
          job_status = Form526JobStatus.find_by(job_id: jid)
          expect(job_status.form526_submission_id).to eq(submission.id)
          expect(job_status.job_class).to eq('BackupSubmission')
          expect(job_status.job_id).to eq(jid)
          expect(job_status.status).to eq('retryable_error')
          error = job_status.bgjob_errors
          expect(error.first.last['error_class']).to eq('StandardError')
          expect(error.first.last['error_message']).to eq('foo')
        end
      end
    end
  end

  describe '.perform_async, enabled, and converts non-pdf evidence to pdf' do
    before do
      allow(Settings.form526_backup).to receive_messages(submission_method: 'single', enabled: true)
    end

    let!(:submission) { create(:form526_submission, :with_non_pdf_uploads, user_account:) }
    let!(:upload_data) { submission.form[Form526Submission::FORM_526_UPLOADS] }

    context 'converts non-pdf files to pdf' do
      before do
        upload_data.each do |ud|
          filename = ud['name']
          file = Rack::Test::UploadedFile.new("spec/fixtures/files/#{filename}",
                                              "application/#{File.basename(filename)}")
          sea = SupportingEvidenceAttachment.find_or_create_by(guid: ud['confirmationCode'])
          sea.set_file_data!(file)
          sea.save!
        end
      end

      it 'converts and submits' do
        new_form_data = submission.saved_claim.parsed_form
        new_form_data['startedFormVersion'] = nil
        submission.saved_claim.form = new_form_data.to_json
        submission.saved_claim.save
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response_generate_pdf') do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
              jid = subject.perform_async(submission.id)
              last = subject.jobs.last
              jid_from_jobs = last['jid']
              expect(jid).to eq(jid_from_jobs)
              described_class.drain
              expect(jid).not_to be_empty
              job_status = Form526JobStatus.last
              expect(job_status.form526_submission_id).to eq(submission.id)
              expect(job_status.job_class).to eq('BackupSubmission')
              expect(job_status.job_id).to eq(jid)
              expect(job_status.status).to eq('success')
              submission = Form526Submission.last
              expect(submission.backup_submitted_claim_id).not_to be_nil
            end
          end
        end
      end
    end
  end
end
