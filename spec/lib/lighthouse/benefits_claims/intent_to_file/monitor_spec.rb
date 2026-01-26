# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

RSpec.describe BenefitsClaims::IntentToFile::Monitor do
  let(:monitor) { described_class.new }
  let(:itf_stats_key) { described_class::STATSD_KEY_PREFIX }
  let(:itf_v1_stats_key) { described_class::STATSD_V1_KEY_PREFIX }
  let(:claim) { create(:pensions_saved_claim) }
  let(:ipf) { create(:in_progress_form, user_account: current_user.user_account) }

  context 'with all params supplied' do
    let(:current_user) { create(:user, :with_terms_of_use_agreement) }
    let(:monitor_error) { create(:monitor_error) }

    describe '#track_create_itf_initiated' do
      it 'logs a create ITF initiated' do
        tags = ['itf_type:pension', 'version:v0']
        log = "Lighthouse::CreateIntentToFileJob create pension ITF initiated for form ##{ipf.id}"
        payload = {
          itf_type: 'pension',
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid
        }
        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.initiated", tags:)
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

        tags = ['itf_type:pension', 'version:v0']
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF active record found'
        payload = {
          itf_type: 'pension',
          itf_created: itf_found&.dig('data', 'attributes', 'creationDate'),
          itf_expires: itf_found&.dig('data', 'attributes', 'expirationDate'),
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid
        }
        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.active_found", tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_itf_active_found('pension', ipf.created_at, current_user.user_account_uuid, itf_found)
      end
    end

    describe '#track_create_itf_begun' do
      it 'logs a create ITF begun' do
        tags = ['itf_type:pension', 'version:v0']
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF begun'
        payload = {
          itf_type: 'pension',
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.begun", tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_itf_begun('pension', ipf.created_at, current_user.user_account_uuid)
      end
    end

    describe '#track_create_itf_success' do
      it 'logs a create ITF success' do
        tags = ['itf_type:pension', 'version:v0']
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF succeeded'
        payload = {
          itf_type: 'pension',
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.success", tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_itf_success('pension', ipf.created_at, current_user.user_account_uuid)
      end
    end

    describe '#track_create_itf_failure' do
      it 'logs a create ITF failure' do
        tags = ['itf_type:pension', 'version:v0']
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF failed'
        payload = {
          itf_type: 'pension',
          form_start_date: ipf.created_at,
          user_account_uuid: current_user.user_account_uuid,
          errors: monitor_error.message
        }

        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.failure", tags:)
        expect(Rails.logger).to receive(:warn).with(log, payload)

        monitor.track_create_itf_failure('pension', ipf.created_at, current_user.user_account_uuid, monitor_error)
      end
    end

    describe '#track_create_itf_exhaustion' do
      it 'logs a create ITF exhaustion' do
        tags = ["form_id:#{ipf.form_id}", 'itf_type:pension', 'version:v0']
        log = 'Lighthouse::CreateIntentToFileJob create pension ITF exhausted'
        payload = {
          error: monitor_error.message,
          itf_type: 'pension',
          form_start_date: ipf.created_at.to_s,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(monitor).to receive(:log_silent_failure).with(payload, current_user.user_account_uuid, anything)
        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.exhausted", tags:)
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_create_itf_exhaustion('pension', ipf, monitor_error.message)
      end
    end

    describe '#track_missing_user_icn' do
      it 'logs a missing user ICN' do
        tags = ["form_id:#{ipf.form_id}", 'version:v0']
        log = 'V0 InProgressFormsController async ITF user.icn is blank'
        payload = {
          error: monitor_error.message,
          in_progress_form_id: ipf.id,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with('user.icn.blank', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_user_icn(ipf, monitor_error)
      end
    end

    describe '#track_missing_user_pid' do
      it 'logs a missing user PID' do
        tags = ["form_id:#{ipf.form_id}", 'version:v0']
        log = 'V0 InProgressFormsController async ITF user.participant_id is blank'
        payload = {
          error: monitor_error.message,
          in_progress_form_id: ipf.id,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with('user.participant_id.blank', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_user_pid(ipf, monitor_error)
      end
    end

    describe '#track_missing_form' do
      it 'logs a missing form' do
        tags = ["form_id:#{ipf.form_id}", 'version:v0']
        log = 'V0 InProgressFormsController async ITF form is missing'
        payload = {
          error: monitor_error.message,
          in_progress_form_id: ipf.id,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with('form.missing', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_form(ipf, monitor_error)
      end
    end

    describe '#track_invalid_itf_type' do
      it 'logs an invalid ITF type' do
        tags = ["form_id:#{ipf.form_id}", 'version:v0']
        log = 'V0 InProgressFormsController async ITF invalid ITF type'
        payload = {
          error: monitor_error.message,
          in_progress_form_id: ipf.id,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with('itf.type.invalid', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_invalid_itf_type(ipf, monitor_error)
      end
    end

    describe '#track_show_itf' do
      it 'logs a show ITF' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'version:v1']
        log = 'IntentToFilesController ITF show'
        payload = {
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with("#{itf_v1_stats_key}.pension.show", tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_show_itf('21P-527EZ', 'pension', current_user.uuid)
      end
    end

    describe '#track_submit_itf' do
      it 'logs a submit ITF' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'version:v1']
        log = 'IntentToFilesController ITF submit'
        payload = {
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with("#{itf_v1_stats_key}.pension.submit", tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_submit_itf('21P-527EZ', 'pension', current_user.uuid)
      end
    end

    describe '#track_itf_controller_error' do
      it 'logs an ITF controller error' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'method:post', 'version:v1']
        log = 'IntentToFilesController pension ITF controller error'
        payload = {
          error: 'error',
          method: 'post',
          itf_type: 'pension',
          form_id: '21P-527EZ'
        }

        expect(StatsD).to receive(:increment).with('v1.itf.error', tags:)
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_itf_controller_error('post', '21P-527EZ', 'pension', 'error')
      end
    end

    describe '#track_missing_user_icn_itf_controller' do
      it 'logs a missing user ICN' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'method:post', 'version:v1']
        log = 'IntentToFilesController ITF user.icn is blank'
        payload = {
          error: 'error',
          method: 'post',
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with('v1.user.icn.blank', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_user_icn_itf_controller('post', '21P-527EZ', 'pension', current_user.uuid, 'error')
      end
    end

    describe '#track_missing_user_pid_itf_controller' do
      it 'logs a missing user PID' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'method:post', 'version:v1']
        log = 'IntentToFilesController ITF user.participant_id is blank'
        payload = {
          error: 'error',
          method: 'post',
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with('v1.user.participant_id.blank', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_user_pid_itf_controller('post', '21P-527EZ', 'pension', current_user.uuid, 'error')
      end
    end

    describe '#track_invalid_itf_type_itf_controller' do
      it 'logs an invalid ITF type' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'method:post', 'version:v1']
        log = 'IntentToFilesController ITF invalid ITF type'
        payload = {
          error: 'error',
          method: 'post',
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with('v1.itf.type.invalid', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_invalid_itf_type_itf_controller('post', '21P-527EZ', 'pension', current_user.uuid, 'error')
      end
    end
  end
end
