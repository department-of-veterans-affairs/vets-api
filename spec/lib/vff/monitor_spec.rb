# frozen_string_literal: true

require 'rails_helper'
require 'vff/monitor'
require 'support/shared_examples/monitor_shared_examples'

RSpec.describe VFF::Monitor do
  let(:monitor) { described_class.new }
  let(:user_account) { create(:user_account) }
  let(:form_submission) { create(:form_submission, form_type: '21-0966', user_account: user_account) }
  let(:form_submission_attempt) { create(:form_submission_attempt, form_submission: form_submission) }

  describe 'constants' do
    it 'defines VFF_FORM_IDS with all expected form types' do
      expected_forms = %w[21-0966 21-4142 21-10210 21-0972 21P-0847 20-10206 20-10207 21-0845]
      expect(described_class::VFF_FORM_IDS).to eq(expected_forms)
      expect(described_class::VFF_FORM_IDS).to be_frozen
    end

    it 'defines StatsD key constants' do
      expect(described_class::BENEFITS_INTAKE_STATS_KEY).to eq('vff.benefits_intake')
      expect(described_class::EMAIL_NOTIFICATION_STATS_KEY).to eq('vff.email_notification')
      expect(described_class::FORM_SUBMISSION_STATS_KEY).to eq('vff.form_submission')
    end

    it_behaves_like 'detects form types correctly', %w[21-0966 21-4142 21-10210 21-0972 21P-0847 20-10206 20-10207 21-0845]
  end

  describe '#initialize' do
    it_behaves_like 'a zero silent failures monitor', 'veteran-facing-forms'
  end

  describe '#track_benefits_intake_failure' do
    let(:context) do
      {
        form_id: '21-0966',
        saved_claim_id: 123,
        benefits_intake_uuid: 'test-uuid-123'
      }
    end

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)
    end

    context 'when no email attempted' do
      it 'logs silent failure' do
        expected_context = {
          form_id: '21-0966',
          claim_id: 123,
          benefits_intake_uuid: 'test-uuid-123',
          form_submission_id: form_submission.id,
          form_submission_created_at: form_submission.created_at,
          latest_attempt_id: form_submission.latest_attempt&.id,
          latest_attempt_state: form_submission.latest_attempt&.aasm_state,
          user_account_id: user_account.id
        }

        expect(monitor).to receive(:log_silent_failure).with(
          expected_context,
          user_account.id,
          hash_including(:call_location)
        )

        monitor.track_benefits_intake_failure(context, form_submission: form_submission)
      end

      it 'increments VFF-specific StatsD metrics' do
        expect(StatsD).to receive(:increment).with(
          'vff.benefits_intake.failure',
          tags: ['form_id:21-0966', 'service:veteran-facing-forms']
        )
        expect(StatsD).to receive(:increment).with(
          'vff.benefits_intake.failure.all_forms',
          tags: ['service:veteran-facing-forms']
        )

        monitor.track_benefits_intake_failure(context, form_submission: form_submission)
      end

      it 'logs detailed information' do
        expect(Rails.logger).to receive(:error).with(
          'VFF Benefits Intake failure tracked',
          hash_including(
            service: 'veteran-facing-forms',
            form_id: '21-0966',
            email_attempted: false,
            email_success: false
          )
        )

        monitor.track_benefits_intake_failure(context, form_submission: form_submission)
      end
    end

    context 'when email attempted and succeeded' do
      it 'logs silent failure avoided' do
        expect(monitor).to receive(:log_silent_failure_avoided)

        monitor.track_benefits_intake_failure(
          context,
          form_submission: form_submission,
          email_attempted: true,
          email_success: true
        )
      end
    end

    context 'when email attempted but failed' do
      it 'logs silent failure no confirmation' do
        expect(monitor).to receive(:log_silent_failure_no_confirmation)

        monitor.track_benefits_intake_failure(
          context,
          form_submission: form_submission,
          email_attempted: true,
          email_success: false
        )
      end
    end

    context 'without form_submission' do
      it 'logs with basic context only' do
        expected_context = {
          form_id: '21-0966',
          claim_id: 123,
          benefits_intake_uuid: 'test-uuid-123'
        }

        expect(monitor).to receive(:log_silent_failure).with(
          expected_context,
          nil,
          hash_including(:call_location)
        )

        monitor.track_benefits_intake_failure(context)
      end
    end
  end

  describe '#track_form_submission_failure' do
    let(:error_details) { { lighthouse_error_code: 'ERR123' } }

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)
      allow(monitor).to receive(:log_silent_failure)
    end

    it 'logs silent failure with comprehensive context' do
      expected_context = {
        form_id: form_submission.form_type,
        form_submission_id: form_submission.id,
        form_submission_attempt_id: form_submission_attempt.id,
        benefits_intake_uuid: form_submission_attempt.benefits_intake_uuid,
        failure_type: 'expired',
        lighthouse_updated_at: form_submission_attempt.lighthouse_updated_at,
        error_message: form_submission_attempt.error_message,
        lighthouse_error_code: 'ERR123'
      }

      expect(monitor).to receive(:log_silent_failure).with(
        expected_context,
        user_account.id,
        hash_including(:call_location)
      )

      monitor.track_form_submission_failure(
        form_submission,
        form_submission_attempt,
        'expired',
        error_details
      )
    end

    it 'increments failure type specific metrics' do
      expect(StatsD).to receive(:increment).with(
        'vff.form_submission.expired',
        tags: ['form_id:21-4142', 'service:veteran-facing-forms']
      )

      monitor.track_form_submission_failure(
        form_submission,
        form_submission_attempt,
        'expired',
        error_details
      )
    end

    it 'logs with appropriate message' do
      expect(Rails.logger).to receive(:error).with(
        'VFF Form submission expired failure',
        hash_including(
          service: 'veteran-facing-forms',
          email_attempted: false,
          email_success: false
        )
      )

      monitor.track_form_submission_failure(
        form_submission,
        form_submission_attempt,
        'expired',
        error_details
      )
    end
  end

  describe 'email notification tracking' do
    let(:form_type) { '21-0966' }
    let(:confirmation_number) { 'CONF123' }

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    describe '#track_email_notification_attempt' do
      it 'increments attempt metric' do
        expect(StatsD).to receive(:increment).with(
          'vff.email_notification.attempt',
          tags: ['form_id:21-0966', 'service:veteran-facing-forms']
        )

        monitor.track_email_notification_attempt(form_type, confirmation_number)
      end

      it 'logs attempt information' do
        expect(Rails.logger).to receive(:info).with(
          'VFF email notification attempted',
          hash_including(
            service: 'veteran-facing-forms',
            form_id: '21-0966',
            confirmation_number: 'CONF123'
          )
        )

        monitor.track_email_notification_attempt(form_type, confirmation_number)
      end
    end

    describe '#track_email_notification_success' do
      it 'increments success metric' do
        expect(StatsD).to receive(:increment).with(
          'vff.email_notification.success',
          tags: ['form_id:21-0966', 'service:veteran-facing-forms']
        )

        monitor.track_email_notification_success(form_type, confirmation_number)
      end

      it 'logs success information' do
        expect(Rails.logger).to receive(:info).with(
          'VFF email notification succeeded',
          hash_including(
            service: 'veteran-facing-forms',
            form_id: '21-0966',
            confirmation_number: 'CONF123'
          )
        )

        monitor.track_email_notification_success(form_type, confirmation_number)
      end
    end

    describe '#track_email_notification_failure' do
      let(:error) { StandardError.new('Email service unavailable') }

      it 'increments failure metric' do
        expect(StatsD).to receive(:increment).with(
          'vff.email_notification.failure',
          tags: ['form_id:21-0966', 'service:veteran-facing-forms']
        )

        monitor.track_email_notification_failure(form_type, confirmation_number, error)
      end

      it 'logs failure information with error details' do
        expect(Rails.logger).to receive(:error).with(
          'VFF email notification failed',
          hash_including(
            service: 'veteran-facing-forms',
            form_id: '21-0966',
            confirmation_number: 'CONF123',
            error_class: 'StandardError',
            error_message: 'Email service unavailable'
          )
        )

        monitor.track_email_notification_failure(form_type, confirmation_number, error)
      end
    end
  end

  describe 'private methods' do
    describe '#build_failure_context' do
      let(:context) do
        {
          form_id: '21-0966',
          saved_claim_id: 123,
          benefits_intake_uuid: 'test-uuid'
        }
      end

      context 'without form_submission' do
        it 'returns basic context only' do
          result = monitor.send(:build_failure_context, context, nil)
          
          expect(result).to eq({
            form_id: '21-0966',
            claim_id: 123,
            benefits_intake_uuid: 'test-uuid'
          })
        end
      end

      context 'with form_submission' do
        it 'returns enriched context' do
          result = monitor.send(:build_failure_context, context, form_submission)
          
          expect(result).to include(
            form_id: '21-0966',
            claim_id: 123,
            benefits_intake_uuid: 'test-uuid',
            form_submission_id: form_submission.id,
            form_submission_created_at: form_submission.created_at,
            user_account_id: user_account.id
          )
        end
      end
    end

    describe '#extract_user_account_uuid' do
      it 'returns user_account_id when form_submission has user_account' do
        result = monitor.send(:extract_user_account_uuid, form_submission)
        expect(result).to eq(user_account.id)
      end

      it 'returns nil when form_submission is nil' do
        result = monitor.send(:extract_user_account_uuid, nil)
        expect(result).to be_nil
      end

      it 'returns nil when form_submission has no user_account' do
        form_submission.update!(user_account: nil)
        result = monitor.send(:extract_user_account_uuid, form_submission)
        expect(result).to be_nil
      end
    end

    describe '.vff_form?' do
      it 'returns true for VFF form IDs' do
        VFF::Monitor::VFF_FORM_IDS.each do |form_id|
          expect(described_class.vff_form?(form_id)).to be true
        end
      end

      it 'returns false for non-VFF form IDs' do
        non_vff_forms = ['686C-674', '28-8832', '28-1900', 'UNKNOWN-FORM']
        non_vff_forms.each do |form_id|
          expect(described_class.vff_form?(form_id)).to be false
        end
      end
    end
  end

  describe 'integration with ZeroSilentFailures::Monitor' do
    let(:context) { { test: 'context' } }
    let(:user_uuid) { 'test-uuid' }

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)
    end

    it 'calls log_silent_failure from parent class' do
      expect(monitor).to receive(:log_silent_failure).and_call_original
      
      monitor.track_benefits_intake_failure(
        { form_id: '21-0966', saved_claim_id: 123, benefits_intake_uuid: 'uuid' }
      )
    end

    it 'calls log_silent_failure_avoided from parent class' do
      expect(monitor).to receive(:log_silent_failure_avoided).and_call_original
      
      monitor.track_benefits_intake_failure(
        { form_id: '21-0966', saved_claim_id: 123, benefits_intake_uuid: 'uuid' },
        email_attempted: true,
        email_success: true
      )
    end

    it 'calls log_silent_failure_no_confirmation from parent class' do
      expect(monitor).to receive(:log_silent_failure_no_confirmation).and_call_original
      
      monitor.track_benefits_intake_failure(
        { form_id: '21-0966', saved_claim_id: 123, benefits_intake_uuid: 'uuid' },
        email_attempted: true,
        email_success: false
      )
    end
  end
end