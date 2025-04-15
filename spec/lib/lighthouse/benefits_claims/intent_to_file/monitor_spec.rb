# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

RSpec.describe BenefitsClaims::IntentToFile::Monitor do
  let(:monitor) { described_class.new }
  let(:itf_stats_key) { described_class::STATSD_KEY_PREFIX }
  let(:claim) { create(:pensions_saved_claim) }
  let(:ipf) { create(:in_progress_form) }

  context 'with all params supplied' do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }

    describe '#track_create_itf_initiated' do
      it 'logs a create ITF initiated' do
        log = "Lighthouse::CreateIntentToFileJob create pension ITF initiated for form ##{ipf.id}"
        payload = {
          itf_type: 'pension',
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid
        }
        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.initiated")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_itf_initiated('pension', ipf.created_at, current_user.user_account_uuid, ipf.id)
      end
    end

    describe '#track_create_itf_active_found' do
      it 'logs a create ITF active found' do
        itf_found = { 'data' =>
          { 'id' => '293372',
            'type' => 'intent_to_file',
            'attributes' =>
            { 'creationDate' => '2025-01-29T08:10:11-06:00',
              'expirationDate' => '2026-01-29T08:10:11-06:00',
              'type' => 'pension',
              'status' => 'active' } } }

        log = 'Lighthouse::CreateIntentToFileJob create pension ITF active record found'
        payload = {
          itf_type: 'pension',
          itf_created: itf_found&.dig('data', 'attributes', 'creationDate'),
          itf_expires: itf_found&.dig('data', 'attributes', 'expirationDate'),
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid
        }
        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.active_found")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_itf_active_found('pension', ipf.created_at, current_user.user_account_uuid, itf_found)
      end
    end

    describe '#track_create_itf_begun' do
      it 'logs a create ITF begun' do
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF begun'
        payload = {
          itf_type: 'pension',
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.begun")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_itf_begun('pension', ipf.created_at, current_user.user_account_uuid)
      end
    end

    describe '#track_create_itf_success' do
      it 'logs a create ITF success' do
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF succeeded'
        payload = {
          itf_type: 'pension',
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.success")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_itf_success('pension', ipf.created_at, current_user.user_account_uuid)
      end
    end

    describe '#track_create_itf_failure' do
      it 'logs a create ITF failure' do
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF failed'
        payload = {
          itf_type: 'pension',
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid,
          errors: monitor_error.message
        }

        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.failure")
        expect(Rails.logger).to receive(:warn).with(log, payload)

        monitor.track_create_itf_failure('pension', ipf.created_at, current_user.user_account_uuid, monitor_error)
      end
    end

    describe '#track_create_itf_exhaustion' do
      it 'logs a create ITF exhaustion' do
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF exhausted'
        payload = {
          error: monitor_error.message,
          itf_type: 'pension',
          form_start_date: ipf.created_at.to_s,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(monitor).to receive(:log_silent_failure).with(payload, current_user.user_account_uuid, anything)
        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.exhausted")
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_create_itf_exhaustion('pension', ipf, monitor_error.message)
      end
    end

    describe '#track_missing_user_icn' do
      it 'logs a missing user ICN' do
        log = 'V0 InProgressFormsController async ITF user.icn is blank'
        payload = {
          error: monitor_error.message,
          in_progress_form_id: ipf.id,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with('user.icn.blank')
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_user_icn(ipf, monitor_error)
      end
    end

    describe '#track_missing_user_pid' do
      it 'logs a missing user PID' do
        log = 'V0 InProgressFormsController async ITF user.participant_id is blank'
        payload = {
          error: monitor_error.message,
          in_progress_form_id: ipf.id,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with('user.participant_id.blank')
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_user_pid(ipf, monitor_error)
      end
    end

    describe '#track_missing_form' do
      it 'logs a missing form' do
        log = 'V0 InProgressFormsController async ITF form is missing'
        payload = {
          error: monitor_error.message,
          in_progress_form_id: ipf.id,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with('form.missing')
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_form(ipf, monitor_error)
      end
    end

    describe '#track_invalid_itf_type' do
      it 'logs an invalid ITF type' do
        log = 'V0 InProgressFormsController async ITF invalid ITF type'
        payload = {
          error: monitor_error.message,
          in_progress_form_id: ipf.id,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with('itf.type.invalid')
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_invalid_itf_type(ipf, monitor_error)
      end
    end
  end
end
