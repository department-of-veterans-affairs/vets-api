# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Burials::Monitor do
  let(:monitor) { described_class.new }
  let(:claim) { create(:burials_saved_claim) }
  let(:ipf) { create(:in_progress_form) }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:lh_service) { OpenStruct.new(uuid: 'uuid') }

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
        log = '21P-530EZ fetching submission failed'
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
        log = '21P-530EZ submission to Sidekiq begun'
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
        log = '21P-530EZ submission validation error'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [],
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

    describe '#track_create_error' do
      it 'logs sidekiq failed' do
        log = '21P-530EZ submission to Sidekiq failed'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [],
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
        log = '21P-530EZ submission to Sidekiq success'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [],
          tags: monitor.tags
        }

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

    describe '#track_process_attachment_error' do
      it 'logs process attachment failed' do
        log = '21P-530EZ process attachment error'
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          errors: [],
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

    describe '#track_submission_begun' do
      it 'logs sidekiq job started' do
        log = 'Burial 21P-530EZ submission to LH begun'
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

        log = 'Burial 21P-530EZ submission to LH attempted'
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
        log = 'Burial 21P-530EZ submission to LH succeeded'
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
        log = 'Burial 21P-530EZ submission to LH failed, retrying'
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
          notification = double(Burials::NotificationEmail)

          msg = { 'args' => [claim.id, current_user.uuid] }

          log = 'Burial 21P-530EZ submission to LH exhausted!'
          payload = {
            confirmation_number: claim.confirmation_number,
            user_account_uuid: current_user.uuid,
            form_id: claim.form_id,
            claim_id: claim.id, # pulled from msg.args
            message: msg,
            tags: monitor.tags
          }

          expect(Burials::NotificationEmail).to receive(:new).with(claim.id).and_return notification
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

          log = 'Burial 21P-530EZ submission to LH exhausted!'
          payload = {
            confirmation_number: nil,
            user_account_uuid: current_user.uuid,
            form_id: nil,
            claim_id: claim.id, # pulled from msg.args
            message: msg,
            tags: monitor.tags
          }

          expect(Burials::NotificationEmail).not_to receive(:new)
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

      describe '#track_document_processing_error' do
        it 'Log document processing failure' do
          log = 'Burial 21P-530EZ process document failure'
          payload = {
            claim_id: claim.id,
            benefits_intake_uuid: lh_service.uuid,
            confirmation_number: claim.confirmation_number,
            user_account_uuid: current_user.uuid,
            message: monitor_error.message,
            tags: monitor.tags
          }

          expect(monitor).to receive(:track_request).with(
            'error',
            log,
            "#{submission_stats_key}.process_document_failure",
            call_location: anything,
            **payload
          )

          monitor.track_document_processing_error(claim, lh_service, current_user.uuid, monitor_error)
        end
      end

      describe '#track_metadata_generation_error' do
        it 'Log metadata generation failures' do
          log = 'Burial 21P-530EZ generate metadata failure'
          payload = {
            claim_id: claim.id,
            benefits_intake_uuid: lh_service.uuid,
            confirmation_number: claim.confirmation_number,
            user_account_uuid: current_user.uuid,
            message: monitor_error.message,
            tags: monitor.tags
          }

          expect(monitor).to receive(:track_request).with(
            'error',
            log,
            "#{submission_stats_key}.generate_metadata_failure",
            call_location: anything,
            **payload
          )

          monitor.track_metadata_generation_error(claim, lh_service, current_user.uuid, monitor_error)
        end
      end

      describe '#track_submission_polling_error' do
        it 'Log submission polling failures' do
          log = 'Burial 21P-530EZ submission polling failure'
          payload = {
            claim_id: claim.id,
            benefits_intake_uuid: lh_service.uuid,
            confirmation_number: claim.confirmation_number,
            user_account_uuid: current_user.uuid,
            message: monitor_error.message,
            tags: monitor.tags
          }

          expect(monitor).to receive(:track_request).with(
            'error',
            log,
            "#{submission_stats_key}.submission_polling_failure",
            call_location: anything,
            **payload
          )

          monitor.track_submission_polling_error(claim, lh_service, current_user.uuid, monitor_error)
        end
      end

      describe '#track_send_submitted_email_failure' do
        it 'logs sidekiq job send_submitted_email error' do
          log = 'Burial 21P-530EZ send_submitted_email failed'
          payload = {
            claim_id: claim.id,
            user_account_uuid: current_user.uuid,
            benefits_intake_uuid: lh_service.uuid,
            confirmation_number: claim.confirmation_number,
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
    end

    describe '#track_send_confirmation_email_failure' do
      it 'logs sidekiq job send_confirmation_email error' do
        log = 'Burial 21P-530EZ send_confirmation_email failed'
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
        log = 'Burial 21P-530EZ send_submitted_email failed'
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
        log = 'Burial 21P-530EZ cleanup failed'
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
  end
end
