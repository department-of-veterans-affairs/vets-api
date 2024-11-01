# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/burials/monitor'

RSpec.describe Burials::Monitor do
  let(:monitor) { described_class.new }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:claim) { create(:burial_claim_v2) }
  let(:ipf) { create(:in_progress_form) }

  context 'with all params supplied' do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }
    let(:lh_service) { OpenStruct.new(uuid: 'uuid') }

    describe '#track_show404' do
      it 'logs a not found error' do
        log = '21P-530EZ submission not found'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          message: monitor_error.message
        }

        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_show404(claim.confirmation_number, current_user, monitor_error)
      end
    end

    describe '#track_show_error' do
      it 'logs a submission failed error' do
        log = '21P-530EZ fetching submission failed'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          message: monitor_error.message
        }

        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_show_error(claim.confirmation_number, current_user, monitor_error)
      end
    end

    describe '#track_create_attempt' do
      it 'logs sidekiq started' do
        log = '21P-530EZ submission to Sidekiq begun'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          statsd: "#{claim_stats_key}.attempt"
        }

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.attempt")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_attempt(claim, current_user)
      end
    end

    describe '#track_create_validation_error' do
      it 'logs create failed' do
        log = '21P-530EZ submission validation error'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          in_progress_form_id: ipf.id,
          errors: [], # mock claim does not have `errors`
          statsd: "#{claim_stats_key}.validation_error"
        }

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.validation_error")
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_create_validation_error(ipf, claim, current_user)
      end
    end

    describe '#track_process_attachment_error' do
      it 'logs process attachment failed' do
        log = '21P-530EZ process attachment error'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          in_progress_form_id: ipf.id,
          errors: [], # mock claim does not have `errors`
          statsd: "#{claim_stats_key}.process_attachment_error"
        }

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.process_attachment_error")
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_process_attachment_error(ipf, claim, current_user)
      end
    end

    describe '#track_create_error' do
      it 'logs sidekiq failed' do
        log = '21P-530EZ submission to Sidekiq failed'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          in_progress_form_id: ipf.id,
          errors: [], # mock claim does not have `errors`
          message: monitor_error.message,
          statsd: "#{claim_stats_key}.failure"
        }

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.failure")
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_create_error(ipf, claim, current_user, monitor_error)
      end
    end

    describe '#track_create_success' do
      it 'logs sidekiq success' do
        log = '21P-530EZ submission to Sidekiq success'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          in_progress_form_id: ipf.id,
          statsd: "#{claim_stats_key}.success"
        }
        claim.form_start_date = Time.zone.now

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.success")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_success(ipf, claim, current_user)
      end
    end

    describe '#track_submission_exhaustion' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, current_user.uuid] }

        log = 'Lighthouse::SubmitBenefitsIntakeClaim Burial 21P-530EZ submission to LH exhausted!'
        payload = {
          form_id: claim.form_id,
          claim_id: claim.id,
          confirmation_number: claim.confirmation_number,
          message: msg
        }

        expect(monitor).to receive(:log_silent_failure).with(payload, current_user.uuid, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
        expect(Rails.logger).to receive(:error).with(log, user_uuid: current_user.uuid, **payload)

        monitor.track_submission_exhaustion(msg, claim)
      end
    end
  end
end
