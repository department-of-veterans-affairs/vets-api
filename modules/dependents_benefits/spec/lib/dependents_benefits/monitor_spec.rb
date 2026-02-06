# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/monitor'

RSpec.describe DependentsBenefits::Monitor do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
  end

  let(:monitor) { described_class.new }
  let(:claim) { create(:dependents_claim) }
  let(:ipf) { create(:in_progress_form) }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:lh_service) { OpenStruct.new(uuid: 'uuid') }
  let(:message_prefix) { "#{described_class} #{DependentsBenefits::FORM_ID}" }
  let(:current_user) { create(:user) }
  let(:monitor_error) { create(:monitor_error) }

  def base_payload(extras = {})
    {
      confirmation_number: claim.confirmation_number,
      user_account_uuid: current_user.user_account_uuid,
      claim_id: claim.id,
      form_id: claim.form_id,
      tags: monitor.tags
    }.merge(extras)
  end

  def submission_payload(extras = {})
    base_payload({
      benefits_intake_uuid: lh_service.uuid,
      user_account_uuid: current_user.user_account_uuid
    }.merge(extras))
  end

  describe '#service_name' do
    it 'returns expected name' do
      expect(monitor.send(:service_name)).to eq('dependents-benefits-application')
    end
  end

  describe '#track_show404' do
    it 'logs a not found error' do
      log = "#{message_prefix} submission not found"
      payload = base_payload({ claim_id: nil, form_id: nil, error: monitor_error.message })

      expect(monitor).to receive(:track_request).with(
        :error, log, claim_stats_key, call_location: anything, **payload
      )
      monitor.track_show404(claim.confirmation_number, current_user, monitor_error)
    end
  end

  describe '#track_show_error' do
    it 'logs a submission failed error' do
      log = "#{message_prefix} fetching submission failed"
      payload = base_payload({ claim_id: nil, form_id: nil, error: monitor_error.message })

      expect(monitor).to receive(:track_request).with(
        :error, log, claim_stats_key, call_location: anything, **payload
      )
      monitor.track_show_error(claim.confirmation_number, current_user, monitor_error)
    end
  end

  describe '#track_create_attempt' do
    it 'logs sidekiq started' do
      log = "#{message_prefix} submission to Sidekiq begun"
      payload = base_payload

      expect(monitor).to receive(:track_request).with(
        :info, log, "#{claim_stats_key}.attempt", call_location: anything, **payload
      )
      monitor.track_create_attempt(claim, current_user)
    end
  end

  describe '#track_create_validation_error' do
    it 'logs create failed' do
      log = "#{message_prefix} submission validation error"
      payload = base_payload({ in_progress_form_id: ipf.id, errors: [] })

      expect(monitor).to receive(:track_request).with(
        :error, log, "#{claim_stats_key}.validation_error", call_location: anything, **payload
      )
      monitor.track_create_validation_error(ipf, claim, current_user)
    end
  end

  describe '#track_create_error' do
    it 'logs sidekiq failed' do
      log = "#{message_prefix} submission to Sidekiq failed"
      payload = base_payload({ in_progress_form_id: ipf.id, errors: [], error: monitor_error.message })

      expect(monitor).to receive(:track_request).with(
        :error, log, "#{claim_stats_key}.failure", call_location: anything, **payload
      )
      monitor.track_create_error(ipf, claim, current_user, monitor_error)
    end
  end

  describe '#track_create_success' do
    it 'logs sidekiq success' do
      log = "#{message_prefix} submission to Sidekiq success"
      payload = base_payload({ in_progress_form_id: ipf.id })

      expect(monitor).to receive(:track_request).with(
        :info, log, "#{claim_stats_key}.success", call_location: anything, **payload
      )
      monitor.track_create_success(ipf, claim, current_user)
    end
  end

  describe '#track_process_attachment_error' do
    it 'logs process attachment failed' do
      log = "#{message_prefix} process attachment error"
      payload = base_payload({ in_progress_form_id: ipf.id, errors: [] })

      expect(monitor).to receive(:track_request).with(
        :error, log, "#{claim_stats_key}.process_attachment_error", call_location: anything, **payload
      )
      monitor.track_process_attachment_error(ipf, claim, current_user)
    end
  end

  describe '#track_submission_begun' do
    it 'logs sidekiq job started' do
      log = "#{message_prefix} submission to LH begun"
      payload = submission_payload

      expect(monitor).to receive(:track_request).with(
        :info, log, "#{submission_stats_key}.begun", call_location: anything, **payload
      )
      monitor.track_submission_begun(claim, lh_service, current_user.uuid)
    end
  end

  describe '#track_submission_attempted' do
    it 'logs sidekiq job upload attempt' do
      upload = { file: 'pdf-file-path', attachments: %w[pdf-attachment1 pdf-attachment2] }
      log = "#{message_prefix} submission to LH attempted"
      payload = submission_payload(upload)

      expect(monitor).to receive(:track_request).with(
        :info, log, "#{submission_stats_key}.attempt", call_location: anything, **payload
      )
      monitor.track_submission_attempted(claim, lh_service, current_user.uuid, upload)
    end
  end

  describe '#track_submission_success' do
    it 'logs sidekiq job successful' do
      log = "#{message_prefix} submission to LH succeeded"
      payload = submission_payload

      expect(monitor).to receive(:track_request).with(
        :info, log, "#{submission_stats_key}.success", call_location: anything, **payload
      )
      monitor.track_submission_success(claim, lh_service, current_user.uuid)
    end
  end

  describe '#track_submission_retry' do
    it 'logs sidekiq job failure and retry' do
      log = "#{message_prefix} submission to LH failed, retrying"
      payload = submission_payload({ error: monitor_error.message })

      expect(monitor).to receive(:track_request).with(
        :warn, log, "#{submission_stats_key}.failure", call_location: anything, **payload
      )
      monitor.track_submission_retry(claim, lh_service, current_user.uuid, monitor_error)
    end
  end

  describe '#track_submission_exhaustion' do
    context 'without a claim parameter' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, current_user.uuid], 'error_message' => 'Final error message' }
        log = "#{message_prefix} submission to LH exhausted!"

        expect(monitor).to receive(:track_request).with(
          :error,
          'Silent failure!',
          'silent_failure',
          hash_including(
            call_location: anything,
            claim_id: claim.id,
            user_account_uuid: current_user.user_account_uuid,
            error: msg,
            tags: monitor.tags
          )
        )

        expect(monitor).to receive(:track_request).with(
          :error, log, "#{submission_stats_key}.exhausted",
          hash_including(
            call_location: anything,
            claim_id: claim.id,
            user_account_uuid: current_user.user_account_uuid,
            confirmation_number: nil,
            form_id: nil,
            error: msg['error_message'],
            tags: monitor.tags
          )
        )
        monitor.track_submission_exhaustion(msg, nil)
      end
    end
  end

  describe '#track_send_email_failure' do
    %w[confirmation submitted].each do |email_type|
      it "logs sidekiq job send_#{email_type}_email error" do
        log = "#{message_prefix} send_#{email_type}_email failed"
        payload = submission_payload({ error: monitor_error.message })

        expect(monitor).to receive(:track_request).with(
          :warn, log, "#{submission_stats_key}.send_#{email_type}_failed", call_location: anything, **payload
        )
        monitor.track_send_email_failure(claim, lh_service, current_user.uuid, email_type, monitor_error)
      end
    end
  end

  describe '#track_file_cleanup_error' do
    it 'logs sidekiq job ensure file cleanup error' do
      log = "#{message_prefix} cleanup failed"
      payload = submission_payload({ error: monitor_error.message })

      expect(monitor).to receive(:track_request).with(
        :error, log, "#{submission_stats_key}.cleanup_failed", call_location: anything, **payload
      )
      monitor.track_file_cleanup_error(claim, lh_service, current_user.uuid, monitor_error)
    end
  end

  describe '#track_pension_related_submission' do
    it 'logs pension-related submission with parent_claim_id' do
      log = 'Submitted pension-related claim'
      payload = { parent_claim_id: claim.id, tags: [] }

      expect(monitor).to receive(:track_info_event).with(
        log, described_class::PENSION_SUBMISSION_STATS_KEY, **payload
      )
      monitor.track_pension_related_submission('Submitted pension-related claim', parent_claim_id: claim.id)
    end
  end

  describe '#track_unknown_claim_type' do
    it 'logs unknown claim type error' do
      log = 'Unknown Dependents form type for claim'
      payload = { claim_id: claim.id, error: monitor_error, tags: [] }

      expect(monitor).to receive(:track_warning_event).with(
        log, described_class::UNKNOWN_CLAIM_TYPE_STATS_KEY, **payload
      )
      monitor.track_unknown_claim_type(log, claim_id: claim.id, error: monitor_error)
    end
  end

  describe '#track_error_event' do
    it 'calls submit_event with error level' do
      message = 'Test error message'
      stats_key = 'test.stats.key'
      context = { test: 'context' }

      expect(monitor).to receive(:submit_event).with(:error, message, stats_key, **context)
      monitor.track_error_event(message, stats_key, **context)
    end
  end

  describe '#track_info_event' do
    it 'calls submit_event with info level' do
      message = 'Test info message'
      stats_key = 'test.stats.key'
      context = { test: 'context' }

      expect(monitor).to receive(:submit_event).with(:info, message, stats_key, **context)
      monitor.track_info_event(message, stats_key, **context)
    end
  end

  describe '#track_warning_event' do
    it 'calls submit_event with warn level' do
      message = 'Test warning message'
      stats_key = 'test.stats.key'
      context = { test: 'context' }

      expect(monitor).to receive(:submit_event).with(:warn, message, stats_key, **context)
      monitor.track_warning_event(message, stats_key, **context)
    end
  end

  describe '#track_processor_error' do
    it 'logs processor error with action tag' do
      message = 'Processor error occurred'
      action = 'process_claim'
      context = { form_type: '686c' }

      expect(monitor).to receive(:track_error_event).with(
        message, described_class::PROCESSOR_STATS_KEY, form_type: '686c', tags: ["action:#{action}"]
      )
      monitor.track_processor_error(message, action, **context)
    end
  end

  describe '#track_processor_info' do
    it 'logs processor info with action tag' do
      message = 'Processor completed successfully'
      action = 'process_claim'
      context = { form_type: '686c' }

      expect(monitor).to receive(:track_info_event).with(
        message, described_class::PROCESSOR_STATS_KEY, form_type: '686c', tags: ["action:#{action}"]
      )
      monitor.track_processor_info(message, action, **context)
    end
  end

  describe '#track_submission_info' do
    it 'logs submission info with action tag' do
      message = 'Submission processing started'
      action = 'start_processing'
      context = { submission_id: '12345' }

      expect(monitor).to receive(:track_info_event).with(
        message, described_class::SUBMISSION_STATS_KEY, submission_id: '12345', tags: ["action:#{action}"]
      )
      monitor.track_submission_info(message, action, **context)
    end
  end

  describe '#track_submission_error' do
    it 'logs submission error with action tag' do
      message = 'Submission failed'
      action = 'submit_to_lh'
      context = { submission_id: '12345' }

      expect(monitor).to receive(:track_error_event).with(
        message, described_class::SUBMISSION_STATS_KEY, submission_id: '12345', tags: ["action:#{action}"]
      )
      monitor.track_submission_error(message, action, **context)
    end
  end

  describe '#track_backup_job_info' do
    it 'logs backup job info with action tag' do
      message = 'Backup job started'
      action = 'start_backup'
      context = { parent_claim_id: claim.id }

      expect(monitor).to receive(:track_info_event).with(
        message, described_class::BACKUP_JOB_STATS_KEY, parent_claim_id: claim.id, tags: ["action:#{action}"]
      )
      monitor.track_backup_job_info(message, action, **context)
    end
  end

  describe '#track_backup_job_warning' do
    it 'logs backup job warning with action tag' do
      message = 'Backup job encountered warning'
      action = 'backup_processing'
      context = { parent_claim_id: claim.id }

      expect(monitor).to receive(:track_warning_event).with(
        message, described_class::BACKUP_JOB_STATS_KEY, parent_claim_id: claim.id, tags: ["action:#{action}"]
      )
      monitor.track_backup_job_warning(message, action, **context)
    end
  end

  describe '#track_backup_job_error' do
    it 'logs backup job error with action tag' do
      message = 'Backup job failed'
      action = 'submit_backup'
      context = { parent_claim_id: claim.id }

      expect(monitor).to receive(:track_error_event).with(
        message, described_class::BACKUP_JOB_STATS_KEY, parent_claim_id: claim.id, tags: ["action:#{action}"]
      )
      monitor.track_backup_job_error(message, action, **context)
    end
  end

  describe '#track_prefill_warning' do
    it 'logs prefill warning with action tag' do
      message = 'Form prefill encountered warning'
      action = 'prefill_form'
      context = { form_type: '686c' }

      expect(monitor).to receive(:track_warning_event).with(
        message, described_class::PREFILL_STATS_KEY, form_type: '686c', tags: ["action:#{action}"]
      )
      monitor.track_prefill_warning(message, action, **context)
    end
  end

  describe '#track_user_data_error' do
    it 'logs user data error with action tag' do
      message = 'User data extraction failed'
      action = 'extract_user_data'
      context = { form_type: '686c' }

      expect(monitor).to receive(:track_error_event).with(
        message, described_class::CLAIM_STATS_KEY, form_type: '686c', tags: ["action:#{action}"]
      )
      monitor.track_user_data_error(message, action, **context)
    end
  end

  describe '#track_user_data_warning' do
    it 'logs user data warning with action tag' do
      message = 'User data extraction warning'
      action = 'extract_user_data'
      context = { form_type: '686c' }

      expect(monitor).to receive(:track_warning_event).with(
        message, described_class::CLAIM_STATS_KEY, form_type: '686c', tags: ["action:#{action}"]
      )
      monitor.track_user_data_warning(message, action, **context)
    end
  end

  describe '#claim_stats_key' do
    it 'returns expected claim stats key' do
      expect(monitor.send(:claim_stats_key)).to eq(described_class::CLAIM_STATS_KEY)
    end
  end

  describe '#submission_stats_key' do
    it 'returns expected submission stats key' do
      expect(monitor.send(:submission_stats_key)).to eq(described_class::SUBMISSION_STATS_KEY)
    end
  end

  describe '#name' do
    it 'returns class name' do
      expect(monitor.send(:name)).to eq('DependentsBenefits::Monitor')
    end
  end

  describe '#form_id' do
    it 'returns expected form id' do
      expect(monitor.send(:form_id)).to eq(DependentsBenefits::FORM_ID)
    end
  end
end
