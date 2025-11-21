# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'decision_reviews:remediation rake tasks', type: :task do
  before :all do
    Rake.application.rake_require '../rakelib/decision_reviews_recovered_failures_remediation'
    Rake::Task.define_task(:environment)
  end

  # Stub S3 uploads to prevent actual AWS calls during tests
  before do
    allow(Settings).to receive(:reports).and_return(
      double(aws: double(
        region: 'us-east-1',
        access_key_id: 'test-key',
        secret_access_key: 'test-secret',
        bucket: 'test-bucket'
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

  describe 'decision_reviews:remediation:send_recovery_emails' do
    let(:saved_claim) { create(:saved_claim_higher_level_review) }
    let(:appeal_submission) do
      create(:appeal_submission,
             saved_claim_hlr: saved_claim,
             user_account:,
             failure_notification_sent_at: 1.day.ago)
    end

    let(:run_rake_task) do
      Rake::Task['decision_reviews:remediation:send_recovery_emails'].reenable
      ENV['APPEAL_SUBMISSION_IDS'] = appeal_submission.id.to_s
      ENV['VANOTIFY_TEMPLATE_ID'] = 'test-template-id'
      ENV['DRY_RUN'] = 'true'
      Rake.application.invoke_task 'decision_reviews:remediation:send_recovery_emails'
    end

    after do
      ENV.delete('APPEAL_SUBMISSION_IDS')
      ENV.delete('VANOTIFY_TEMPLATE_ID')
      ENV.delete('DRY_RUN')
    end

    context 'with no appeal submission IDs' do
      it 'exits with error message' do
        ENV.delete('APPEAL_SUBMISSION_IDS')
        ENV['VANOTIFY_TEMPLATE_ID'] = 'test-template-id'

        # Use begin/rescue to catch SystemExit without propagating exit code
        exit_raised = false
        begin
          silently do
            Rake::Task['decision_reviews:remediation:send_recovery_emails'].reenable
            Rake.application.invoke_task 'decision_reviews:remediation:send_recovery_emails'
          end
        rescue SystemExit
          exit_raised = true
        end

        expect(exit_raised).to be true
      end
    end

    context 'with no VA Notify template ID' do
      it 'exits with error message' do
        ENV['APPEAL_SUBMISSION_IDS'] = appeal_submission.id.to_s
        ENV.delete('VANOTIFY_TEMPLATE_ID')

        # Use begin/rescue to catch SystemExit without propagating exit code
        exit_raised = false
        begin
          silently do
            Rake::Task['decision_reviews:remediation:send_recovery_emails'].reenable
            Rake.application.invoke_task 'decision_reviews:remediation:send_recovery_emails'
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

      before do
        ENV['DRY_RUN'] = 'false'
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
        allow(vanotify_service).to receive(:send_email).and_return({ 'id' => 'notification-123' })

        # Stub MPI profile
        mpi_profile = double(given_names: ['John'])
        allow(appeal_submission).to receive_messages(get_mpi_profile: mpi_profile, current_email_address: email_address)

        # Stub AppealSubmission.where to return our stubbed submission
        allow(AppealSubmission).to receive(:where).and_return(
          double(includes: [appeal_submission])
        )
      end

      it 'sends email via VA Notify' do
        expect(vanotify_service).to receive(:send_email).with(
          hash_including(
            email_address:,
            template_id: 'test-template-id',
            personalisation: hash_including(
              'first_name' => 'John'
            )
          )
        )
        silently do
          Rake::Task['decision_reviews:remediation:send_recovery_emails'].reenable
          Rake.application.invoke_task 'decision_reviews:remediation:send_recovery_emails'
        end
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
