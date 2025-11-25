# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'decision_reviews:remediation rake tasks', type: :task do
  before :all do
    Rake.application.rake_require '../rakelib/decision_reviews_recovered_failures_remediation'
    Rake.application.rake_require '../rakelib/decision_reviews_recovery_emails'
    Rake::Task.define_task(:environment)
  end

  # Stub S3 uploads to prevent actual AWS calls during tests
  before do
    allow(Settings).to receive_messages(
      reports: double(aws: double(
        region: 'us-east-1',
        access_key_id: 'test-key',
        secret_access_key: 'test-secret',
        bucket: 'test-bucket'
      )),
      vanotify: double(services: double(
        benefits_decision_review: double(
          api_key: 'test-api-key',
          template_id: double(
            evidence_recovery_email: 'evidence-template-id',
            form_recovery_email: 'form-template-id'
          )
        )
      ))
    )

    # Stub S3 resource and operations
    s3_resource = instance_double(Aws::S3::Resource)
    s3_bucket = instance_double(Aws::S3::Bucket)
    s3_object = instance_double(Aws::S3::Object)

    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
    allow(s3_resource).to receive(:bucket).and_return(s3_bucket)
    allow(s3_bucket).to receive(:object).and_return(s3_object)
    allow(s3_object).to receive(:put).and_return(true)

    # Stub DecisionReviews constants for email sending tests
    stub_const('DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP', {
                 'HLR' => 'higher-level-review',
                 'NOD' => 'board-appeal',
                 'SC' => 'supplemental-claims'
               })
  end

  let(:user_account) { create(:user_account) }

  describe 'decision_reviews:remediation:clear_recovered_statuses' do
    let(:saved_claim) do
      create(:saved_claim_higher_level_review, metadata: {
        status: 'error',
        updatedAt: '2025-11-20T20:35:56.103Z',
        createdAt: '2025-11-18T01:09:10.553Z',
        uploads: []
      }.to_json)
    end
    let(:appeal_submission) do
      create(:appeal_submission,
             saved_claim_hlr: saved_claim,
             user_account:,
             failure_notification_sent_at: 1.day.ago)
    end

    let(:run_rake_task) do
      Rake::Task['decision_reviews:remediation:clear_recovered_statuses'].reenable
      ENV['APPEAL_SUBMISSION_IDS'] = appeal_submission.id.to_s
      ENV['DRY_RUN'] = 'true'
      ENV.delete('LIGHTHOUSE_UPLOAD_IDS')
      Rake.application.invoke_task 'decision_reviews:remediation:clear_recovered_statuses'
    end

    after do
      ENV.delete('APPEAL_SUBMISSION_IDS')
      ENV.delete('LIGHTHOUSE_UPLOAD_IDS')
      ENV.delete('DRY_RUN')
    end

    context 'with no IDs provided' do
      it 'exits with error message' do
        ENV.delete('APPEAL_SUBMISSION_IDS')
        ENV.delete('LIGHTHOUSE_UPLOAD_IDS')

        # Use begin/rescue to catch SystemExit without propagating exit code
        exit_raised = false
        begin
          silently do
            Rake::Task['decision_reviews:remediation:clear_recovered_statuses'].reenable
            Rake.application.invoke_task 'decision_reviews:remediation:clear_recovered_statuses'
          end
        rescue SystemExit
          exit_raised = true
        end

        expect(exit_raised).to be true
      end
    end

    context 'with valid appeal submission IDs in dry run mode' do
      it 'runs without errors' do
        expect { silently { run_rake_task } }.not_to raise_error
      end

      it 'does not modify the database' do
        expect do
          silently { run_rake_task }
        end.not_to(change { saved_claim.reload.metadata })
      end
    end

    context 'with valid appeal submission IDs in live mode' do
      let(:run_live_task) do
        Rake::Task['decision_reviews:remediation:clear_recovered_statuses'].reenable
        ENV['APPEAL_SUBMISSION_IDS'] = appeal_submission.id.to_s
        ENV['DRY_RUN'] = 'false'
        Rake.application.invoke_task 'decision_reviews:remediation:clear_recovered_statuses'
      end

      it 'clears error status from metadata' do
        silently { run_live_task }
        metadata = JSON.parse(saved_claim.reload.metadata)
        expect(metadata).not_to have_key('status')
        expect(metadata).to have_key('uploads')
      end
    end

    context 'with evidence upload IDs' do
      let(:upload_saved_claim) do
        create(:saved_claim_higher_level_review, metadata: {
          status: 'complete',
          updatedAt: '2025-11-20T20:35:56.103Z',
          createdAt: '2025-11-18T01:09:10.553Z',
          uploads: [
            { id: 'test-uuid-123',
              status: 'error',
              detail: 'Upstream status: Errors: ERR-EMMS-FAILED, Packet submission validation failed.',
              createDate: '2025-11-15T23:07:40.892Z',
              updateDate: '2025-11-15T23:07:40.892Z' }
          ]
        }.to_json)
      end
      let(:appeal_submission_with_upload) do
        create(:appeal_submission,
               saved_claim_hlr: upload_saved_claim,
               user_account:,
               failure_notification_sent_at: 1.day.ago)
      end
      let(:evidence_upload) do
        create(:appeal_submission_upload,
               appeal_submission: appeal_submission_with_upload,
               lighthouse_upload_id: 'test-uuid-123',
               failure_notification_sent_at: 1.day.ago)
      end

      let(:run_evidence_task) do
        Rake::Task['decision_reviews:remediation:clear_recovered_statuses'].reenable
        ENV['LIGHTHOUSE_UPLOAD_IDS'] = evidence_upload.lighthouse_upload_id
        ENV['DRY_RUN'] = 'false'
        ENV.delete('APPEAL_SUBMISSION_IDS')
        Rake.application.invoke_task 'decision_reviews:remediation:clear_recovered_statuses'
      end

      it 'clears error status from upload metadata' do
        silently { run_evidence_task }
        metadata = JSON.parse(upload_saved_claim.reload.metadata)
        upload_entry = metadata['uploads'].first
        expect(upload_entry['id']).to eq('test-uuid-123')
        expect(upload_entry).not_to have_key('status')
        expect(upload_entry).not_to have_key('detail')
      end
    end
  end

  describe 'decision_reviews:remediation:clear_november_2025_recovered_statuses' do
    let(:run_rake_task) do
      Rake::Task['decision_reviews:remediation:clear_november_2025_recovered_statuses'].reenable
      ENV['DRY_RUN'] = 'true'
      Rake.application.invoke_task 'decision_reviews:remediation:clear_november_2025_recovered_statuses'
    end

    after do
      ENV.delete('DRY_RUN')
    end

    it 'runs without errors in dry run mode' do
      expect { silently { run_rake_task } }.not_to raise_error
    end
  end

  describe 'decision_reviews:remediation:send_evidence_recovery_emails' do
    let(:saved_claim) { create(:saved_claim_higher_level_review) }
    let(:appeal_submission) do
      create(:appeal_submission,
             saved_claim_hlr: saved_claim,
             user_account:)
    end
    let(:evidence_upload) do
      create(:appeal_submission_upload,
             appeal_submission:,
             lighthouse_upload_id: 'test-uuid-123',
             failure_notification_sent_at: 1.day.ago)
    end

    let(:run_rake_task) do
      Rake::Task['decision_reviews:remediation:send_evidence_recovery_emails'].reenable
      ENV['LIGHTHOUSE_UPLOAD_IDS'] = evidence_upload.lighthouse_upload_id
      ENV['DRY_RUN'] = 'true'
      Rake.application.invoke_task 'decision_reviews:remediation:send_evidence_recovery_emails'
    end

    after do
      ENV.delete('LIGHTHOUSE_UPLOAD_IDS')
      ENV.delete('DRY_RUN')
    end

    context 'with no lighthouse upload IDs' do
      it 'exits with error message' do
        ENV.delete('LIGHTHOUSE_UPLOAD_IDS')

        exit_raised = false
        begin
          silently do
            Rake::Task['decision_reviews:remediation:send_evidence_recovery_emails'].reenable
            Rake.application.invoke_task 'decision_reviews:remediation:send_evidence_recovery_emails'
          end
        rescue SystemExit
          exit_raised = true
        end

        expect(exit_raised).to be true
      end
    end

    context 'with valid inputs in dry run mode' do
      it 'runs without errors' do
        expect { silently { run_rake_task } }.not_to raise_error
      end

      it 'does not send any emails' do
        expect_any_instance_of(VaNotify::Service).not_to receive(:send_email)
        silently { run_rake_task }
      end
    end

    context 'with valid inputs in live mode' do
      let(:vanotify_service) { instance_double(VaNotify::Service) }
      let(:email_address) { 'test@example.com' }

      let(:run_live_rake_task) do
        Rake::Task['decision_reviews:remediation:send_evidence_recovery_emails'].reenable
        ENV['LIGHTHOUSE_UPLOAD_IDS'] = evidence_upload.lighthouse_upload_id
        ENV['DRY_RUN'] = 'false'
        Rake.application.invoke_task 'decision_reviews:remediation:send_evidence_recovery_emails'
      end

      before do
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
        allow(vanotify_service).to receive(:send_email).and_return({ 'id' => 'notification-123' })

        # Stub MPI profile
        mpi_profile = double(given_names: ['John'])
        allow(appeal_submission).to receive_messages(get_mpi_profile: mpi_profile, current_email_address: email_address)

        # Stub masked filename on upload
        allow(evidence_upload).to receive(:masked_attachment_filename).and_return('eviXXXXXXce.pdf')

        # Stub AppealSubmissionUpload.where to return our stubbed upload
        # Need to stub the full chain: where().includes() and also .count
        upload_relation = double('AppealSubmissionUpload::ActiveRecord_Relation')
        allow(upload_relation).to receive_messages(includes: [evidence_upload], count: 1)
        allow(AppealSubmissionUpload).to receive(:where).and_return(upload_relation)
      end

      it 'sends email via VA Notify with correct personalization' do
        expect(vanotify_service).to receive(:send_email).with(
          hash_including(
            email_address:,
            template_id: 'evidence-template-id',
            personalisation: hash_including(
              'first_name' => 'John',
              'filename' => 'eviXXXXXXce.pdf',
              'date_submitted' => kind_of(String)
            )
          )
        )
        silently { run_live_rake_task }
      end
    end

    context 'when upload has no failure notification' do
      let(:no_failure_upload) do
        create(:appeal_submission_upload,
               appeal_submission:,
               lighthouse_upload_id: 'test-uuid-456',
               failure_notification_sent_at: nil)
      end

      it 'skips the upload' do
        ENV['LIGHTHOUSE_UPLOAD_IDS'] = no_failure_upload.lighthouse_upload_id
        expect_any_instance_of(VaNotify::Service).not_to receive(:send_email)
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end
  end

  describe 'decision_reviews:remediation:send_form_recovery_emails' do
    let(:saved_claim) { create(:saved_claim_higher_level_review) }
    let(:appeal_submission) do
      create(:appeal_submission,
             saved_claim_hlr: saved_claim,
             user_account:,
             failure_notification_sent_at: 1.day.ago)
    end

    let(:run_rake_task) do
      Rake::Task['decision_reviews:remediation:send_form_recovery_emails'].reenable
      ENV['APPEAL_SUBMISSION_IDS'] = appeal_submission.id.to_s
      ENV['DRY_RUN'] = 'true'
      Rake.application.invoke_task 'decision_reviews:remediation:send_form_recovery_emails'
    end

    after do
      ENV.delete('APPEAL_SUBMISSION_IDS')
      ENV.delete('DRY_RUN')
    end

    context 'with no appeal submission IDs' do
      it 'exits with error message' do
        ENV.delete('APPEAL_SUBMISSION_IDS')

        exit_raised = false
        begin
          silently do
            Rake::Task['decision_reviews:remediation:send_form_recovery_emails'].reenable
            Rake.application.invoke_task 'decision_reviews:remediation:send_form_recovery_emails'
          end
        rescue SystemExit
          exit_raised = true
        end

        expect(exit_raised).to be true
      end
    end

    context 'with valid inputs in dry run mode' do
      it 'runs without errors' do
        expect { silently { run_rake_task } }.not_to raise_error
      end

      it 'does not send any emails' do
        expect_any_instance_of(VaNotify::Service).not_to receive(:send_email)
        silently { run_rake_task }
      end
    end

    context 'with valid inputs in live mode' do
      let(:vanotify_service) { instance_double(VaNotify::Service) }
      let(:email_address) { 'test@example.com' }

      let(:run_live_rake_task) do
        Rake::Task['decision_reviews:remediation:send_form_recovery_emails'].reenable
        ENV['APPEAL_SUBMISSION_IDS'] = appeal_submission.id.to_s
        ENV['DRY_RUN'] = 'false'
        Rake.application.invoke_task 'decision_reviews:remediation:send_form_recovery_emails'
      end

      before do
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
        allow(vanotify_service).to receive(:send_email).and_return({ 'id' => 'notification-123' })

        # Stub MPI profile
        mpi_profile = double(given_names: ['John'])
        allow(appeal_submission).to receive_messages(get_mpi_profile: mpi_profile, current_email_address: email_address)

        # Stub AppealSubmission.where to return our stubbed submission
        # Need to stub the full chain: where().includes()
        submission_relation = double('AppealSubmission::ActiveRecord_Relation')
        allow(submission_relation).to receive_messages(includes: [appeal_submission], count: 1)
        allow(AppealSubmission).to receive(:where).and_return(submission_relation)
      end

      it 'sends email via VA Notify with correct personalization' do
        expect(vanotify_service).to receive(:send_email).with(
          hash_including(
            email_address:,
            template_id: 'form-template-id',
            personalisation: hash_including(
              'first_name' => 'John',
              'decision_review_type' => 'Notice of Disagreement (Board Appeal)',
              'decision_review_form_id' => 'VA Form 10182',
              'date_submitted' => kind_of(String)
            )
          )
        )
        silently { run_live_rake_task }
      end
    end

    context 'when submission has no failure notification' do
      let(:no_failure_submission) do
        create(:appeal_submission,
               saved_claim_hlr: saved_claim,
               user_account:,
               failure_notification_sent_at: nil)
      end

      it 'skips the submission' do
        ENV['APPEAL_SUBMISSION_IDS'] = no_failure_submission.id.to_s
        expect_any_instance_of(VaNotify::Service).not_to receive(:send_email)
        expect { silently { run_rake_task } }.not_to raise_error
      end
    end

    context 'S3 upload' do
      let(:s3_object) { instance_double(Aws::S3::Object) }

      before do
        # More specific S3 stubbing for this test
        s3_resource = instance_double(Aws::S3::Resource)
        s3_bucket = instance_double(Aws::S3::Bucket)

        allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
        allow(s3_resource).to receive(:bucket).and_return(s3_bucket)
        allow(s3_bucket).to receive(:object).and_return(s3_object)
        allow(s3_object).to receive(:put).and_return(true)
      end

      it 'uploads results to S3 by default' do
        expect(s3_object).to receive(:put).with(
          hash_including(
            content_type: 'text/plain'
          )
        )
        silently { run_rake_task }
      end

      it 'skips S3 upload when UPLOAD_TO_S3=false' do
        ENV['UPLOAD_TO_S3'] = 'false'
        expect(s3_object).not_to receive(:put)
        silently { run_rake_task }
        ENV.delete('UPLOAD_TO_S3')
      end
    end
  end

  describe 'decision_reviews:remediation:send_november_2025_recovery_emails' do
    let(:saved_claim) { create(:saved_claim_higher_level_review) }
    let(:appeal_submission) do
      create(:appeal_submission,
             saved_claim_hlr: saved_claim,
             user_account:,
             failure_notification_sent_at: 1.day.ago)
    end
    let(:evidence_upload) do
      create(:appeal_submission_upload,
             appeal_submission:,
             lighthouse_upload_id: 'test-uuid-123',
             failure_notification_sent_at: 1.day.ago)
    end

    let(:run_rake_task) do
      Rake::Task['decision_reviews:remediation:send_november_2025_recovery_emails'].reenable
      ENV['DRY_RUN'] = 'true'
      Rake.application.invoke_task 'decision_reviews:remediation:send_november_2025_recovery_emails'
    end

    after do
      ENV.delete('DRY_RUN')
      ENV.delete('UPLOAD_TO_S3')
    end

    context 'with dry run mode' do
      it 'runs without errors' do
        expect { silently { run_rake_task } }.not_to raise_error
      end

      it 'does not send any emails' do
        expect_any_instance_of(VaNotify::Service).not_to receive(:send_email)
        silently { run_rake_task }
      end
    end

    context 'S3 upload' do
      let(:s3_object) { instance_double(Aws::S3::Object) }

      before do
        s3_resource = instance_double(Aws::S3::Resource)
        s3_bucket = instance_double(Aws::S3::Bucket)

        allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
        allow(s3_resource).to receive(:bucket).and_return(s3_bucket)
        allow(s3_bucket).to receive(:object).and_return(s3_object)
        allow(s3_object).to receive(:put).and_return(true)
      end

      it 'uploads combined results to S3 by default' do
        expect(s3_object).to receive(:put).with(
          hash_including(
            content_type: 'text/plain'
          )
        )
        silently { run_rake_task }
      end

      it 'skips S3 upload when UPLOAD_TO_S3=false' do
        ENV['UPLOAD_TO_S3'] = 'false'
        expect(s3_object).not_to receive(:put)
        silently { run_rake_task }
      end
    end
  end
end

# Helper to suppress verbose logging during tests
def silently
  # Store the original stderr and stdout in order to restore them later
  @original_stderr = $stderr
  @original_stdout = $stdout

  # Redirect stderr and stdout
  $stderr = $stdout = StringIO.new

  yield

  $stderr = @original_stderr
  $stdout = @original_stdout
  @original_stderr = nil
  @original_stdout = nil
end

def capture_stdout
  original_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = original_stdout
end
