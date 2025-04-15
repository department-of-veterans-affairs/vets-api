# frozen_string_literal: true

require 'rails_helper'
require 'pensions/monitor'

RSpec.describe Pensions::Monitor do
  let(:monitor) { described_class.new }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:claim) { create(:pensions_saved_claim) }
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
          user_account_uuid: current_user.user_account_uuid,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          log,
          claim_stats_key,
          call_location: anything,
          **payload
        )

        monitor.track_show404(claim.confirmation_number, current_user, monitor_error)
      end
    end

    describe '#track_show_error' do
      it 'logs a submission failed error' do
        log = '21P-527EZ fetching submission failed'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          log,
          claim_stats_key,
          call_location: anything,
          **payload
        )

        monitor.track_show_error(claim.confirmation_number, current_user, monitor_error)
      end
    end

    describe '#track_create_attempt' do
      it 'logs sidekiq started' do
        log = '21P-527EZ submission to Sidekiq begun'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'info',
          log,
          "#{claim_stats_key}.attempt",
          call_location: anything,
          **payload
        )

        monitor.track_create_attempt(claim, current_user)
      end
    end

    describe '#track_create_validation_error' do
      it 'logs create failed' do
        log = '21P-527EZ submission validation error'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [], # mock claim does not have `errors`
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          log,
          "#{claim_stats_key}.validation_error",
          call_location: anything,
          **payload
        )

        monitor.track_create_validation_error(ipf, claim, current_user)
      end
    end

    describe '#track_process_attachment_error' do
      it 'logs process attachment failed' do
        log = '21P-527EZ process attachment error'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [], # mock claim does not have `errors`
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          log,
          "#{claim_stats_key}.process_attachment_error",
          call_location: anything,
          **payload
        )

        monitor.track_process_attachment_error(ipf, claim, current_user)
      end
    end

    describe '#track_create_error' do
      it 'logs sidekiq failed' do
        log = '21P-527EZ submission to Sidekiq failed'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [], # mock claim does not have `errors`
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          log,
          "#{claim_stats_key}.failure",
          call_location: anything,
          **payload
        )

        monitor.track_create_error(ipf, claim, current_user, monitor_error)
      end
    end

    describe '#track_create_success' do
      it 'logs sidekiq success' do
        log = '21P-527EZ submission to Sidekiq success'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          tags: monitor.tags
        }
        claim.form_start_date = Time.zone.now

        expect(monitor).to receive(:track_request).with(
          'info',
          log,
          "#{claim_stats_key}.success",
          call_location: anything,
          **payload
        )

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
          user_account_uuid: current_user.uuid,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'info',
          log,
          "#{submission_stats_key}.begun",
          call_location: anything,
          **payload
        )

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
          user_account_uuid: current_user.uuid,
          file: upload[:file],
          attachments: upload[:attachments],
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'info',
          log,
          "#{submission_stats_key}.attempt",
          call_location: anything,
          **payload
        )

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
          user_account_uuid: current_user.uuid,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'info',
          log,
          "#{submission_stats_key}.success",
          call_location: anything,
          **payload
        )

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
          user_account_uuid: current_user.uuid,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'warn',
          log,
          "#{submission_stats_key}.failure",
          call_location: anything,
          **payload
        )

        monitor.track_submission_retry(claim, lh_service, current_user.uuid, monitor_error)
      end
    end

    describe '#track_submission_exhaustion' do
      context 'with a claim parameter' do
        it 'logs sidekiq job exhaustion' do
          notification = double(Pensions::NotificationEmail)

          msg = { 'args' => [claim.id, current_user.uuid] }

          log = 'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!'
          payload = {
            form_id: claim.form_id,
            claim_id: claim.id,
            user_account_uuid: current_user.uuid,
            confirmation_number: claim.confirmation_number,
            message: msg,
            tags: monitor.tags
          }

          expect(Pensions::NotificationEmail).to receive(:new).with(claim.id).and_return notification
          expect(notification).to receive(:deliver).with(:error)

          expect(monitor).to receive(:track_request).with(
            'error',
            log,
            "#{submission_stats_key}.exhausted",
            call_location: anything,
            **payload
          )

          monitor.track_submission_exhaustion(msg, claim)
        end
      end

      context 'without a claim parameter' do
        it 'logs sidekiq job exhaustion' do
          msg = { 'args' => [claim.id, current_user.uuid] }

          log = 'Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!'
          payload = {
            form_id: nil,
            claim_id: claim.id, # pulled from msg.args
            user_account_uuid: current_user.uuid,
            confirmation_number: nil,
            message: msg,
            tags: monitor.tags
          }

          expect(Pensions::NotificationEmail).not_to receive(:new)
          expect(monitor).to receive(:log_silent_failure).with(payload, current_user.uuid, anything)

          expect(monitor).to receive(:track_request).with(
            'error',
            log,
            "#{submission_stats_key}.exhausted",
            call_location: anything,
            **payload
          )

          monitor.track_submission_exhaustion(msg, nil)
        end
      end
    end

    describe '#track_send_confirmation_email_failure' do
      it 'logs sidekiq job send_confirmation_email error' do
        log = 'Lighthouse::PensionBenefitIntakeJob send_confirmation_email failed'
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
          "#{submission_stats_key}.send_confirmation_failed",
          call_location: anything,
          **payload
        )

        monitor.track_send_confirmation_email_failure(claim, lh_service, current_user.uuid, monitor_error)
      end
    end

    describe '#track_send_submitted_email_failure' do
      it 'logs sidekiq job send_submitted_email error' do
        log = 'Lighthouse::PensionBenefitIntakeJob send_submitted_email failed'
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
        log = 'Lighthouse::PensionBenefitIntakeJob cleanup failed'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          error: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          log,
          "#{submission_stats_key}.cleanup_failed",
          call_location: anything,
          **payload
        )

        monitor.track_file_cleanup_error(claim, lh_service, current_user.uuid, monitor_error)
      end
    end

    describe '#track_claim_signature_error' do
      it 'logs sidekiq job custom date failed' do
        log = 'Lighthouse::PensionBenefitIntakeJob custom date failed'
        payload = {
          claim_id: claim.id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          error: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          log,
          "#{submission_stats_key}.custom_date_failed",
          call_location: anything,
          **payload
        )

        monitor.track_claim_signature_error(claim, lh_service, current_user.uuid, monitor_error)
      end
    end
  end
end
