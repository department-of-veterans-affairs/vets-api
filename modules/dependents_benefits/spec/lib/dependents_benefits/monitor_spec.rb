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
        msg = { 'args' => [claim.id, current_user.uuid] }
        log = "#{message_prefix} submission to LH exhausted!"

        payload = base_payload({ confirmation_number: nil, form_id: nil, error: msg })

        expect(monitor).to receive(:log_silent_failure).with(payload.compact, current_user.uuid, anything)
        expect(monitor).to receive(:track_request).with(
          :error, log, "#{submission_stats_key}.exhausted", call_location: anything, **payload, error: { 'args' => [
            anything, current_user.uuid
          ] }
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
end
