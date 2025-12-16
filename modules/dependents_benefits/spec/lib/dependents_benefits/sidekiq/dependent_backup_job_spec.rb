# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/dependent_backup_job'

RSpec.describe DependentsBenefits::Sidekiq::DependentBackupJob, type: :job do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(pdf_stamper_instance).at_least(:once)
    allow(pdf_stamper_instance).to receive(:run).and_return('/tmp/stamped_1.pdf', '/tmp/stamped_2.pdf',
                                                            '/tmp/final_stamped.pdf')

    allow(BenefitsIntakeService::Service).to receive(:new).and_return(lighthouse_mock)
    allow(DependentsBenefits::ClaimProcessor).to receive(:new).and_return(claim_processor)
    allow(claim_processor).to receive(:collect_child_claims).and_return([claim686c, claim674])
  end

  let(:pdf_stamper_instance) { instance_double(PDFUtilities::DatestampPdf) }
  let(:lighthouse_mock) do
    double(:lighthouse_service, uuid: 'uuid', upload_form: OpenStruct.new(success?: true, data: {}))
  end
  let(:parent_claim) { create(:dependents_claim) }
  let(:job) { described_class.new }
  let(:lh_submission) { instance_double(DependentsBenefits::BenefitsIntake::LighthouseSubmission) }
  let(:successful_response) { DependentsBenefits::ServiceResponse.new(status: true) }
  let(:user) { create(:evss_user) }
  let(:user_data) { DependentsBenefits::UserData.new(user, parent_claim.parsed_form).get_user_json }
  let!(:parent_group) { create(:parent_claim_group, parent_claim:, user_data:) }
  let(:monitor_instance) { instance_double(DependentsBenefits::Monitor) }
  let(:claim_processor) { double('DependentsBenefits::ClaimProcessor') }
  let(:claim686c) { create(:add_remove_dependents_claim) }
  let(:claim674) { create(:student_claim) }

  describe '#perform' do
    context 'when job executes successfully' do
      before do
        allow(DependentsBenefits::BenefitsIntake::LighthouseSubmission).to receive(:new).and_return(lh_submission)
      end

      it 'processes the claim and calls required methods' do
        expect(lh_submission).to receive(:initialize_service)
        expect(lh_submission).to receive(:prepare_submission)
        expect(lh_submission).to receive(:upload_to_lh).and_return(successful_response)
        expect(lh_submission).to receive(:cleanup_file_paths)

        expect { job.perform(parent_claim.id) }.not_to raise_error
      end
    end

    context 'when job fails' do
      let(:test_error) { StandardError.new('Test error') }

      before do
        allow(DependentsBenefits::BenefitsIntake::LighthouseSubmission).to receive(:new).and_return(lh_submission)
        allow(lh_submission).to receive(:initialize_service)
        allow(lh_submission).to receive(:prepare_submission).and_raise(test_error)
        allow(job).to receive(:monitor).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_submission_info)
      end

      it 'updates submission to failed, ensures cleanup, and re-raises error' do
        allow(monitor_instance).to receive(:track_submission_error)
        expect(job).to receive(:mark_submission_attempt_failed)
        expect(lh_submission).to receive(:cleanup_file_paths)
        expect do
          job.perform(parent_claim.id)
        end.to raise_error(DependentsBenefits::Sidekiq::DependentSubmissionError, 'Test error')
      end
    end

    context 'when Lighthouse upload fails' do
      before do
        allow(DependentsBenefits::BenefitsIntake::LighthouseSubmission).to receive(:new).and_return(lh_submission)
        allow(lh_submission).to receive(:initialize_service)
        allow(lh_submission).to receive(:prepare_submission)
        allow(lh_submission).to receive(:upload_to_lh).and_raise(StandardError.new('Upload failed'))
        allow(lh_submission).to receive(:cleanup_file_paths)
      end

      it 'raises DependentSubmissionError' do
        expect do
          job.perform(parent_claim.id)
        end.to raise_error(DependentsBenefits::Sidekiq::DependentSubmissionError, 'Upload failed')
      end
    end

    context 'when parent group has already failed' do
      let!(:failed_parent_group) do
        create(:parent_claim_group, status: 'failure', parent_claim:, user_data:)
      end

      before do
        allow(job).to receive(:parent_group).and_return(failed_parent_group)
      end

      it 'still processes the claim and runs submit_to_service' do
        expect(job).to receive(:submit_to_service).and_return(successful_response)
        expect { job.perform(parent_claim.id) }.not_to raise_error
      end
    end
  end

  describe '#handle_job_success' do
    let(:submission) { create(:lighthouse_submission, saved_claim_id: parent_claim.id) }
    let(:submission_attempt) { create(:lighthouse_submission_attempt, submission:) }

    context 'when parent group was previously failed' do
      let!(:failed_parent_group) do
        create(:parent_claim_group, status: 'failure', parent_claim:, user_data:)
      end

      before do
        allow(job).to receive(:parent_group).and_return(failed_parent_group)
      end

      it 'performs all success operations within transaction' do
        expect(job).to receive(:mark_parent_group_processing)
        expect(job).to receive(:mark_submission_attempt_succeeded)
        expect(ActiveRecord::Base).to receive(:transaction).and_yield
        expect(failed_parent_group).to receive(:with_lock).and_yield
        job.handle_job_success
      end
    end

    context 'when success handling fails' do
      let(:test_error) { StandardError.new('Success handling error') }

      before do
        allow(job).to receive(:monitor).and_return(monitor_instance)
        allow(job).to receive(:mark_submission_attempt_succeeded).and_raise(test_error)
        job.instance_variable_set(:@claim_id, parent_claim.id)
      end

      it 'tracks the error without re-raising' do
        expect(monitor_instance).to receive(:track_submission_error)
          .with('Error handling job success', 'success_failure', error: test_error, parent_claim_id: parent_claim.id)
        expect { job.handle_job_success }.not_to raise_error
      end
    end
  end

  describe '#handle_permanent_failure' do
    let(:test_error) { StandardError.new('Permanent failure error') }
    let(:notification_email) { DependentsBenefits::NotificationEmail.new(parent_claim.id) }

    before do
      allow(job).to receive_messages(monitor: monitor_instance, notification_email:)
    end

    it 'sends failure notification and logs silent failure avoided' do
      expect(notification_email).to receive(:deliver).with(:error_686c_674) # rubocop:disable Naming/VariableNumber
      expect(monitor_instance).to receive(:log_silent_failure_avoided)
        .with({ claim_id: parent_claim.id, error: test_error })
      job.handle_permanent_failure(parent_claim.id, test_error)
    end

    context 'when notification sending fails' do
      let(:notification_error) { StandardError.new('Notification failed') }

      it 'logs silent failure as last resort' do
        allow(notification_email).to receive(:deliver).and_raise(notification_error)
        expect(monitor_instance).to receive(:log_silent_failure)
          .with({ claim_id: parent_claim.id, error: notification_error })
        job.handle_permanent_failure(parent_claim.id, notification_error)
      end
    end
  end

  describe '#parent_group_failed?' do
    it 'always returns false for backup job, even when parent group is failed' do
      failed_parent_group = create(:parent_claim_group, status: 'failure', parent_claim:, user_data:)
      allow(job).to receive(:parent_group).and_return(failed_parent_group)

      expect(job.send(:parent_group_failed?)).to be false
    end
  end

  describe '#submit_to_service' do
    before do
      allow(job).to receive(:monitor).and_return(monitor_instance)
      allow(DependentsBenefits::BenefitsIntake::LighthouseSubmission).to receive(:new).and_return(lh_submission)
      allow(lh_submission).to receive(:initialize_service)
      allow(lh_submission).to receive(:prepare_submission)
      allow(lh_submission).to receive(:upload_to_lh)
      allow(lh_submission).to receive(:cleanup_file_paths)
      job.instance_variable_set(:@claim_id, parent_claim.id)
    end

    it 'runs successfully' do
      result = job.send(:submit_to_service)
      expect(result.status).to be true
    end

    it 'ensures cleanup even on error and returns error response' do
      allow(lh_submission).to receive(:prepare_submission).and_raise(StandardError.new('Test error'))
      expect(lh_submission).to receive(:cleanup_file_paths)

      result = job.send(:submit_to_service)
      expect(result.status).to be false
      expect(result.error).to be_a(StandardError)
    end
  end

  describe '.trigger_failure_events' do
    let(:msg) { { 'args' => [parent_claim.id, StandardError.new('Test error')] } }

    it 'handles failure events and sends failure email to veteran' do
      expect { described_class.new.handle_permanent_failure(msg, StandardError.new('Test error')) }.not_to raise_error
    end
  end

  describe 'sidekiq_retries_exhausted callback' do
    it 'calls handle_permanent_failure' do
      msg = { 'args' => [parent_claim.id, 'proc_id'], 'class' => job.class.name }
      exception = StandardError.new('Service failed')

      expect_any_instance_of(described_class).to receive(:handle_permanent_failure)
        .with(parent_claim.id, exception).and_call_original

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end
  end
end
