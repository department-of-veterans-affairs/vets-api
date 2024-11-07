# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/burials/monitor'

RSpec.describe Burials::Monitor do
  let(:monitor) { described_class.new }
  let(:claim) { create(:burial_claim_v2) }
  let(:ipf) { create(:in_progress_form) }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }

  context 'with all params supplied' do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }

    describe '#track_show404' do
      it 'logs a not found error' do
        log = '21P-530EZ submission not found'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          message: monitor_error.message,
          tags: {
            form_id: '21P-530EZ'
          }
        }

        expect_any_instance_of(Logging::Monitor).to receive(:track_request).with(
          'error',
          log,
          claim_stats_key,
          payload,
          anything
        )
        monitor.track_show404(claim.confirmation_number, current_user, monitor_error)
      end
    end

    describe '#track_show_error' do
      it 'logs a submission failed error' do
        log = '21P-530EZ fetching submission failed'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          message: monitor_error.message,
          tags: {
            form_id: '21P-530EZ'
          }
        }

        expect_any_instance_of(Logging::Monitor).to receive(:track_request).with(
          'error',
          log,
          claim_stats_key,
          payload,
          anything
        )
        monitor.track_show_error(claim.confirmation_number, current_user, monitor_error)
      end
    end

    describe '#track_create_attempt' do
      it 'logs sidekiq started' do
        log = '21P-530EZ submission to Sidekiq begun'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          tags: {
            form_id: '21P-530EZ'
          }
        }

        expect_any_instance_of(Logging::Monitor).to receive(:track_request).with(
          'error',
          log,
          "#{claim_stats_key}.attempt",
          payload,
          anything
        )
        monitor.track_create_attempt(claim, current_user)
      end
    end

    describe '#track_create_validation_error' do
      it 'logs create failed' do
        log = '21P-530EZ submission validation error'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [],
          tags: {
            form_id: '21P-530EZ'
          }
        }

        expect_any_instance_of(Logging::Monitor).to receive(:track_request).with(
          'error',
          log,
          "#{claim_stats_key}.validation_error",
          payload,
          anything
        )
        monitor.track_create_validation_error(ipf, claim, current_user)
      end
    end

    describe '#track_process_attachment_error' do
      it 'logs process attachment failed' do
        log = '21P-530EZ process attachment error'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [],
          tags: {
            form_id: '21P-530EZ'
          }
        }

        expect_any_instance_of(Logging::Monitor).to receive(:track_request).with(
          'error',
          log,
          "#{claim_stats_key}.process_attachment_error",
          payload,
          anything
        )
        monitor.track_process_attachment_error(ipf, claim, current_user)
      end
    end

    describe '#track_create_error' do
      it 'logs sidekiq failed' do
        log = '21P-530EZ submission to Sidekiq failed'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [],
          message: monitor_error.message,
          tags: {
            form_id: '21P-530EZ'
          }
        }

        expect_any_instance_of(Logging::Monitor).to receive(:track_request).with(
          'error',
          log,
          "#{claim_stats_key}.failure",
          payload,
          anything
        )
        monitor.track_create_error(ipf, claim, current_user, monitor_error)
      end
    end

    describe '#track_create_success' do
      it 'logs sidekiq success' do
        log = '21P-530EZ submission to Sidekiq success'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [],
          tags: {
            form_id: '21P-530EZ'
          }
        }

        expect_any_instance_of(Logging::Monitor).to receive(:track_request).with(
          'info',
          log,
          "#{claim_stats_key}.success",
          payload,
          anything
        )
        monitor.track_create_success(ipf, claim, current_user)
      end
    end

    describe '#track_submission_exhaustion' do
      context 'with a claim parameter' do
        it 'logs sidekiq job exhaustion' do
          notification = double(Burials::NotificationEmail)

          msg = { 'args' => [claim.id, current_user.uuid] }

          log = 'Lighthouse::SubmitBenefitsIntakeClaim Burial 21P-530EZ submission to LH exhausted!'
          payload = {
            form_id: claim.form_id,
            claim_id: claim.id,
            confirmation_number: claim.confirmation_number,
            message: msg
          }

          expect(Burials::NotificationEmail).to receive(:new).with(claim).and_return notification
          expect(notification).to receive(:deliver).with(:error)
          expect(monitor).to receive(:log_silent_failure_avoided).with(payload, current_user.uuid, anything)

          expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
          expect(Rails.logger).to receive(:error).with(log, user_uuid: current_user.uuid, **payload)

          monitor.track_submission_exhaustion(msg, claim)
        end
      end

      context 'without a claim parameter' do
        it 'logs sidekiq job exhaustion' do
          msg = { 'args' => [claim.id, current_user.uuid] }

          log = 'Lighthouse::SubmitBenefitsIntakeClaim Burial 21P-530EZ submission to LH exhausted!'
          payload = {
            form_id: nil,
            claim_id: claim.id, # pulled from msg.args
            confirmation_number: nil,
            message: msg
          }

          expect(Burials::NotificationEmail).not_to receive(:new)
          expect(monitor).to receive(:log_silent_failure).with(payload, current_user.uuid, anything)

          expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
          expect(Rails.logger).to receive(:error).with(log, user_uuid: current_user.uuid, **payload)

          monitor.track_submission_exhaustion(msg, nil)
        end
      end
    end
  end
end
