# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/form526_job_status_tracker/job_tracker'

describe Sidekiq::Form526JobStatusTracker::JobTracker do
  let(:worker_class) do
    Class.new do
      include Sidekiq::Job
      include Sidekiq::Form526JobStatusTracker::JobTracker
    end
  end

  before do
    Flipper.disable(:disability_compensation_production_tester) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token)
      .and_return('access_token')
  end

  context 'with an exhausted callback message' do
    let(:user_account) { create(:user_account, icn: '123498767V234859') }
    let!(:form526_submission) { create(:form526_submission, user_account:) }
    let!(:form526_job_status) do
      create(:form526_job_status, job_id: msg['jid'], form526_submission:)
    end

    let(:msg) do
      {
        'class' => 'EVSS::DisabilityCompensationForm::SubmitForm526AllClaim',
        'jid' => SecureRandom.uuid,
        'args' => [form526_submission.id],
        'error_message' => 'Did not receive a timely response from an upstream server',
        'error_class' => 'Common::Exceptions::GatewayTimeout'
      }
    end
    let(:backup_klass) { Sidekiq::Form526BackupSubmissionProcess::Submit }

    before { allow(Settings.form526_backup).to receive(:enabled).and_return(true) }

    it 'tracks an exhausted job, with no remaining birls ids' do
      allow_any_instance_of(Form526Submission).to receive(:birls_ids_that_havent_been_tried_yet).and_return([])
      form526_submission.auth_headers.delete('va_eauth_birlsfilenumber')
      form526_submission.save!
      expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_exhausted)
      expect do
        # Expect that an exhausted job, ensures that a backup submission gets queued
        worker_class.job_exhausted(msg, 'stats_key')
        worker_class.drain
      end.to change(backup_klass.jobs, :size).by(1)
      job_status = Form526JobStatus.last
      expect(job_status.status).to eq 'exhausted'
      expect(job_status.job_class).to eq 'SubmitForm526AllClaim'
      expect(job_status.form526_submission_id).to eq form526_submission.id

      expect(job_status.bgjob_errors).to be_a Hash
      key = job_status.bgjob_errors.keys.first
      expect(job_status.bgjob_errors[key].keys).to match_array %w[timestamp caller_method error_class
                                                                  error_message form526_submission_id]
      expect(job_status.bgjob_errors[key]['caller_method']).to match 'job_exhausted'
    end

    it 'tracks an exhausted job, with remaining birls ids' do
      expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_exhausted)
      expect do
        worker_class.job_exhausted(msg, 'stats_key')
        worker_class.drain
      end.not_to change(backup_klass.jobs, :size)
      job_status = Form526JobStatus.last
      expect(job_status.status).to eq 'exhausted'
      expect(job_status.job_class).to eq 'SubmitForm526AllClaim'
      expect(job_status.form526_submission_id).to eq form526_submission.id

      expect(job_status.bgjob_errors).to be_a Hash
      key = job_status.bgjob_errors.keys.first
      expect(job_status.bgjob_errors[key].keys).to match_array %w[timestamp caller_method error_class
                                                                  error_message form526_submission_id]
      expect(job_status.bgjob_errors[key]['caller_method']).to match 'job_exhausted'
    end

    it 'submits a backup submission to Central Mail via Lighthouse Benefits Intake API, if flipper enabled' do
      # Removing the additional_birls from the submission auth headers for this test
      # In order for it to kick off a backup submission, additional_birls must not exist
      allow_any_instance_of(Form526Submission).to receive(:birls_ids_that_havent_been_tried_yet).and_return([])
      form526_submission.auth_headers.delete('va_eauth_birlsfilenumber')

      new_form_data = form526_submission.saved_claim.parsed_form
      new_form_data['startedFormVersion'] = nil
      form526_submission.saved_claim.form = new_form_data.to_json
      form526_submission.saved_claim.save
      form526_submission.save!
      VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
        VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response_generate_pdf') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            expect do
              worker_class.job_exhausted(msg, 'stats_key')
              worker_class.drain
            end.to change(backup_klass.jobs, :size).by(1)
            backup_klass.drain
            expect(Form526JobStatus.last.job_class).to eq('BackupSubmission')
          end
        end
      end
    end
  end

  describe '#with_tracking' do
    let(:worker) { worker_class.new }

    before do
      stub_const('DummyClass::STATSD_KEY_PREFIX', 'dummy.worker')
      allow(worker_class).to receive(:name).and_return('WorkerClass')
      allow(worker).to receive(:jid).and_return('0')
    end

    context 'when code in the block returns from the method' do
      it 'marks the status as successful' do
        # `return` requires defining a method to return from
        def dummy_method
          worker.with_tracking('title', 0, 0) { return }
        end
        dummy_method
        expect(Form526JobStatus.last.status).to eq 'success'
      end
    end

    context 'when code in the block breaks from the block' do
      it 'marks the status as successful' do
        worker.with_tracking('title', 0, 0) { break }
        expect(Form526JobStatus.last.status).to eq 'success'
      end
    end

    context 'when an exception is raised' do
      it 'propagates the exception and does not mark the status as successful' do
        expect do
          worker.with_tracking('title', 0, 0) { raise 'an exception' }
        end.to raise_exception(RuntimeError)
        expect(Form526JobStatus.last.status).to eq 'try'
      end
    end
  end
end
