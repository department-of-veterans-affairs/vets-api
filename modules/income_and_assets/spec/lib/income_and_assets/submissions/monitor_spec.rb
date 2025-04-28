# frozen_string_literal: true

require 'rails_helper'
require 'income_and_assets/submissions/monitor'

RSpec.describe IncomeAndAssets::Submissions::Monitor do
  let(:monitor) { described_class.new }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:claim) { create(:income_and_assets_claim) }
  let(:ipf) { create(:in_progress_form) }

  context 'with all params supplied' do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }
    let(:lh_service) { OpenStruct.new(uuid: 'uuid') }

    describe '#track_submission_begun' do
      it 'logs sidekiq job started' do
        log = 'IncomeAndAssets::BenefitIntakeJob submission to LH begun'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.begun")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_submission_begun(claim, lh_service, current_user.user_account_uuid)
      end
    end

    describe '#track_submission_attempted' do
      it 'logs sidekiq job upload attempt' do
        upload = {
          file: 'pdf-file-path',
          attachments: %w[pdf-attachment1 pdf-attachment2]
        }

        log = 'IncomeAndAssets::BenefitIntakeJob submission to LH attempted'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          file: upload[:file],
          attachments: upload[:attachments]
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.attempt")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_submission_attempted(claim, lh_service, current_user.user_account_uuid, upload)
      end
    end

    describe '#track_submission_success' do
      it 'logs sidekiq job successful' do
        log = 'IncomeAndAssets::BenefitIntakeJob submission to LH succeeded'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.success")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_submission_success(claim, lh_service, current_user.user_account_uuid)
      end
    end

    describe '#track_submission_retry' do
      it 'logs sidekiq job failure and retry' do
        log = 'IncomeAndAssets::BenefitIntakeJob submission to LH failed, retrying'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          message: monitor_error.message
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.failure")
        expect(Rails.logger).to receive(:warn).with(log, payload)

        monitor.track_submission_retry(claim, lh_service, current_user.user_account_uuid, monitor_error)
      end
    end

    describe '#track_submission_exhaustion' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, current_user.user_account_uuid] }

        log = 'IncomeAndAssets::BenefitIntakeJob submission to LH exhausted!'
        payload = {
          claim_id: claim.id,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          message: msg
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_submission_exhaustion(msg, claim)
      end
    end

    describe '#track_send_submitted_email_failure' do
      it 'logs sidekiq job send_submitted_email error' do
        log = 'IncomeAndAssets::BenefitIntakeJob send_submitted_email failed'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'warn',
          log,
          "#{submission_stats_key}.send_submitted_failed",
          call_location: anything,
          **payload
        )

        monitor.track_send_submitted_email_failure(claim, lh_service, current_user.uuid, monitor_error)
      end
    end

    describe '#track_file_cleanup_error' do
      it 'logs sidekiq job ensure file cleanup error' do
        log = 'IncomeAndAssets::BenefitIntakeJob cleanup failed'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          error: monitor_error.message
        }

        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_file_cleanup_error(claim, lh_service, current_user.user_account_uuid, monitor_error)
      end
    end
  end
end
