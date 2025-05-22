# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

RSpec.describe BenefitsClaims::IntentToFile::Monitor do
  let(:monitor) { described_class.new }
  let(:itf_stats_key) { described_class::STATSD_KEY_PREFIX }
  let(:claim) { create(:pensions_saved_claim) }
  let(:ipf) { create(:in_progress_form, user_account: current_user.user_account) }

  context 'with all params supplied' do
    let(:current_user) { create(:user, :with_terms_of_use_agreement) }
    let(:monitor_error) { create(:monitor_error) }

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

    describe '#track_show_itf' do
      it 'logs a show ITF' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension']
        log = 'V0 IntentToFilesController ITF show'
        payload = {
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.show", tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_show_itf('21P-527EZ', 'pension', current_user.uuid)
      end
    end

    describe '#track_submit_itf' do
      it 'logs a submit ITF' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension']
        log = 'V0 IntentToFilesController ITF submit'
        payload = {
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with("#{itf_stats_key}.pension.submit", tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_submit_itf('21P-527EZ', 'pension', current_user.uuid)
      end
    end

    describe '#track_missing_user_icn_itf_controller' do
      it 'logs a missing user ICN' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'method:post']
        log = 'V0 IntentToFilesController ITF user.icn is blank'
        payload = {
          error: 'error',
          method: 'post',
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with('user.icn.blank', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_user_icn_itf_controller('post', '21P-527EZ', 'pension', current_user.uuid, 'error')
      end
    end

    describe '#track_missing_user_pid_itf_controller' do
      it 'logs a missing user PID' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'method:post']
        log = 'V0 IntentToFilesController ITF user.participant_id is blank'
        payload = {
          error: 'error',
          method: 'post',
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with('user.participant_id.blank', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_missing_user_pid_itf_controller('post', '21P-527EZ', 'pension', current_user.uuid, 'error')
      end
    end

    describe '#track_invalid_itf_type_itf_controller' do
      it 'logs an invalid ITF type' do
        tags = ['form_id:21P-527EZ', 'itf_type:pension', 'method:post']
        log = 'V0 IntentToFilesController ITF invalid ITF type'
        payload = {
          error: 'error',
          method: 'post',
          itf_type: 'pension',
          form_id: '21P-527EZ',
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with('itf.type.invalid', tags:)
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_invalid_itf_type_itf_controller('post', '21P-527EZ', 'pension', current_user.uuid, 'error')
      end
    end
  end
end
