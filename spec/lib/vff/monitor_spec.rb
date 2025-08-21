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

    it 'defines StatsD key constant' do
      expect(described_class::BENEFITS_INTAKE_STATS_KEY).to eq('vff.benefits_intake')
    end

    it_behaves_like 'detects form types correctly', [%w[21-0966 21-4142 21-10210 21-0972 21P-0847 20-10206 20-10207 21-0845]]
  end

  describe '#initialize' do
    it 'inherits from ZeroSilentFailures::Monitor' do
      expect(monitor).to be_a(ZeroSilentFailures::Monitor)
    end

    it 'uses correct service name in StatsD tags' do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)

      monitor.track_benefits_intake_failure('test-uuid', '21-0966', false)

      expect(StatsD).to have_received(:increment).with(
        'vff.benefits_intake.failure',
        tags: ['form_id:21-0966', 'service:veteran-facing-forms']
      )
    end

    it 'responds to core ZSF methods' do
      expect(monitor).to respond_to(:log_silent_failure)
      expect(monitor).to respond_to(:log_silent_failure_avoided)
      expect(monitor).to respond_to(:log_silent_failure_no_confirmation)
    end
  end

  describe '#track_benefits_intake_failure' do
    let(:benefits_intake_uuid) { 'test-uuid-123' }
    let(:form_id) { '21-0966' }

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)
    end

    context 'when no email sent' do
      it 'logs silent failure' do
        expected_context = {
          benefits_intake_uuid: benefits_intake_uuid,
          form_id: form_id
        }

        expect(monitor).to receive(:log_silent_failure).with(
          expected_context,
          nil,
          call_location: anything
        )

        monitor.track_benefits_intake_failure(benefits_intake_uuid, form_id, false)
      end

      it 'increments StatsD metrics' do
        expect(StatsD).to receive(:increment).with(
          'vff.benefits_intake.failure',
          tags: ['form_id:21-0966', 'service:veteran-facing-forms']
        )

        monitor.track_benefits_intake_failure(benefits_intake_uuid, form_id, false)
      end

      it 'logs detailed information' do
        expect(Rails.logger).to receive(:error).with(
          'VFF Benefits Intake failure for form 21-0966',
          hash_including(
            service: 'veteran-facing-forms',
            benefits_intake_uuid: benefits_intake_uuid,
            form_id: form_id,
            email_sent: false
          )
        )

        monitor.track_benefits_intake_failure(benefits_intake_uuid, form_id, false)
      end
    end

    context 'when email sent' do
      it 'logs silent failure no confirmation' do
        expected_context = {
          benefits_intake_uuid: benefits_intake_uuid,
          form_id: form_id
        }

        expect(monitor).to receive(:log_silent_failure_no_confirmation).with(
          expected_context,
          nil,
          call_location: anything
        )

        monitor.track_benefits_intake_failure(benefits_intake_uuid, form_id, true)
      end

      it 'increments StatsD metrics' do
        expect(StatsD).to receive(:increment).with(
          'vff.benefits_intake.failure',
          tags: ['form_id:21-0966', 'service:veteran-facing-forms']
        )

        monitor.track_benefits_intake_failure(benefits_intake_uuid, form_id, true)
      end

      it 'logs detailed information' do
        expect(Rails.logger).to receive(:error).with(
          'VFF Benefits Intake failure for form 21-0966',
          hash_including(
            service: 'veteran-facing-forms',
            benefits_intake_uuid: benefits_intake_uuid,
            form_id: form_id,
            email_sent: true
          )
        )

        monitor.track_benefits_intake_failure(benefits_intake_uuid, form_id, true)
      end
    end

  end

  describe '#track_email_notification_failure' do
    let(:form_type) { '21-0966' }
    let(:confirmation_number) { 'CONF123' }
    let(:error) { StandardError.new('Email service unavailable') }

    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)
    end

    it 'increments failure metric' do
      expect(StatsD).to receive(:increment).with(
        'vff.benefits_intake.email_failure',
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