# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/monitor'

RSpec.describe DependentsBenefits::Monitor do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
  end

  let(:monitor) { described_class.new(nil, current_user) }
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

  describe '#track_error_event' do
    it 'calls submit_event with error level using action' do
      message = 'Test error message'
      action = 'test_action'
      context = { test: 'context' }
      expected_context = { test: 'context', tags: ["action:#{action}"] }

      expect(monitor).to receive(:submit_event).with(:error, message, described_class::MODULE_STATS_KEY,
                                                     **expected_context)
      monitor.track_error_event(message, action:, **context)
    end
  end

  describe '#track_info_event' do
    it 'calls submit_event with info level using action' do
      message = 'Test info message'
      action = 'test_action'
      context = { test: 'context', module_stats_key: described_class::PENSION_SUBMISSION_STATS_KEY }
      expected_context = { test: 'context', tags: ["action:#{action}"] }

      expect(monitor).to receive(:submit_event).with(:info, message, described_class::PENSION_SUBMISSION_STATS_KEY,
                                                     **expected_context)
      monitor.track_info_event(message, action:, **context)
    end
  end

  describe '#track_warning_event' do
    it 'calls submit_event with warn level using action' do
      message = 'Test warning message'
      action = 'test_action'
      context = { test: 'context' }
      expected_context = { test: 'context', tags: ["action:#{action}"] }

      expect(monitor).to receive(:submit_event).with(:warn, message, described_class::MODULE_STATS_KEY,
                                                     **expected_context)
      monitor.track_warning_event(message, action:, **context)
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

  describe 'v3 flipper' do
    context 'when v3 is disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, anything).and_return(false) }

      it 'does not include v3 tags' do
        m = described_class.new(nil, current_user)
        expect(m.tags).not_to include('use_v3:true')
        expect(m.tags).not_to include('v3_removal:true')
      end
    end

    context 'when v3 is enabled but removal flow is not set' do
      before { allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, anything).and_return(true) }

      it 'includes use_v3 and v3_removal:false tags' do
        m = described_class.new(claim.id, current_user)
        expect(m.tags).to include('use_v3:true')
        expect(m.tags).to include('v3_removal:false')
      end

      context 'when user is user object' do
        let(:current_user) { create(:user) }

        it 'includes use_v3:true tag' do
          m = described_class.new(nil, current_user)
          expect(m.tags).to include('use_v3:true')
        end
      end

      context 'when user is the generated user struct from DependentSubmissionJob' do
        let(:current_user) do
          OpenStruct.new(
            uuid: 'user-uuid',
            first_name: 'Test',
            last_name: 'User',
            common_name: 'Test User',
            va_profile_email: 'test.user@example.com'
          )
        end

        it 'includes use_v3:true tag' do
          m = described_class.new(nil, current_user)
          expect(m.tags).to include('use_v3:true')
        end
      end
    end

    context 'when v3 is enabled and claim is v3 removal flow' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, anything).and_return(true)
        claim.update(form: { 'is_v3_removal_flow' => true }.to_json)
      end

      it 'includes use_v3 and v3_removal:true tags' do
        m = described_class.new(claim.id, current_user)
        expect(m.tags).to include('use_v3:true')
        expect(m.tags).to include('v3_removal:true')
      end
    end
  end

  describe '#get_tags' do
    it 'does not include use_v3 or v3_removal when user and claim are absent' do
      monitor = described_class.new(nil, nil)

      tags = monitor.tags

      expect(tags).to include('service:dependents-benefits-application')
      expect(tags).not_to include('use_v3:false')
      expect(tags).not_to include('v3_removal:false')
    end

    it 'includes use_v3:false when user is present but v3 flipper is off' do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, anything).and_return(false)
      monitor = described_class.new(nil, current_user)
      tags = monitor.tags
      expect(tags).to include('service:dependents-benefits-application')
      expect(tags).to include('use_v3:false')
      expect(tags).not_to include('v3_removal:false')
    end

    it 'includes use_v3 when user present and includes v3_removal when claim present' do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, current_user).and_return(true)
      monitor = described_class.new(claim.id, current_user)

      tags = monitor.tags
      expect(tags).to include('service:dependents-benefits-application')
      expect(tags).to include('use_v3:true')
      expect(tags).not_to include('use_v3:false')
      expect(tags).to include('v3_removal:false')
    end

    it 'includes use_v3 when user is present' do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, current_user).and_return(true)
      monitor = described_class.new(nil, current_user)

      tags = monitor.tags
      expect(tags).to include('service:dependents-benefits-application')
      expect(tags).to include('use_v3:true')
      expect(tags).not_to include('use_v3:false')
      expect(tags).not_to include('v3_removal:false')
    end

    it 'includes v3_removal when claim is present' do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, current_user).and_return(true)
      monitor = described_class.new(claim.id, current_user)

      tags = monitor.tags
      expect(tags).to include('service:dependents-benefits-application')
      expect(tags).to include('v3_removal:false')
      expect(tags).to include('use_v3:true')
    end
  end
end
