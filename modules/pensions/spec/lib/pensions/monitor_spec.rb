# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/pensions/monitor'

RSpec.describe Pensions::Monitor do
  let(:monitor) { described_class.new }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:claim) { create(:pensions_module_pension_claim) }
  let(:ipf) { create(:in_progress_form) }

  context 'with all params supplied' do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }
    let(:lh_service) { OpenStruct.new(uuid: 'uuid') }

    describe '#track_show404' do
      it 'logs a not found error' do
        log = '21P-527EZ submission not found'
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
        log = '21P-527EZ fetching submission failed'
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
        log = '21P-527EZ submission to Sidekiq begun'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.attempt")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_attempt(claim, current_user)
      end
    end

    describe '#track_create_error' do
      it 'logs sidekiq failed' do
        log = '21P-527EZ submission to Sidekiq failed'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          in_progress_form_id: ipf.id,
          errors: [], # mock claim does not have `errors`
          message: monitor_error.message
        }

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.failure")
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_create_error(ipf, claim, current_user, monitor_error)
      end
    end

    describe '#track_create_success' do
      it 'logs sidekiq success' do
        log = '21P-527EZ submission to Sidekiq success'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          in_progress_form_id: ipf.id
        }
        claim.form_start_date = Time.zone.now

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.success")
        expect(StatsD).to receive(:measure).with('saved_claim.time-to-file', claim.created_at - claim.form_start_date,
                                                 tags: ["form_id:#{claim.form_id}"])
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_success(ipf, claim, current_user)
      end
    end

    describe '#track_submission_begun' do
      it 'logs sidekiq job started' do
        log = 'Lighthouse::PensionBenefitIntakeJob submission to LH begun'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.begun")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_submission_begun(claim, lh_service, current_user.uuid)
      end
    end

    describe '#track_submission_attempted' do
      it 'logs sidekiq job upload attempt' do
        upload = {
          file: 'pdf-file-path',
          attachments: %w[pdf-attachment1 pdf-attachment2]
        }

        log = 'Lighthouse::PensionBenefitIntakeJob submission to LH attempted'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          file: upload[:file],
          attachments: upload[:attachments]
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.attempt")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_submission_attempted(claim, lh_service, current_user.uuid, upload)
      end
    end

    describe '#track_submission_success' do
      it 'logs sidekiq job successful' do
        log = 'Lighthouse::PensionBenefitIntakeJob submission to LH succeeded'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.success")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_submission_success(claim, lh_service, current_user.uuid)
      end
    end

    describe '#track_submission_retry' do
      it 'logs sidekiq job failure and retry' do
        log = 'Lighthouse::PensionBenefitIntakeJob submission to LH failed, retrying'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          message: monitor_error.message
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.failure")
        expect(Rails.logger).to receive(:warn).with(log, payload)

        monitor.track_submission_retry(claim, lh_service, current_user.uuid, monitor_error)
      end
    end

    describe '#track_submission_exhaustion' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, current_user.uuid] }

        log = 'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!'
        payload = {
          claim_id: claim.id,
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          message: msg
        }

        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_submission_exhaustion(msg, claim)
      end
    end

    describe '#track_file_cleanup_error' do
      it 'logs sidekiq job ensure file cleanup error' do
        log = 'Lighthouse::PensionBenefitIntakeJob cleanup failed'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_uuid: current_user.uuid,
          error: monitor_error.message
        }

        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_file_cleanup_error(claim, lh_service, current_user.uuid, monitor_error)
      end
    end
  end
end
