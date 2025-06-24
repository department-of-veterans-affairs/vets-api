# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Burials::Monitor do
  let(:monitor) { described_class.new }
  let(:claim) { create(:burials_saved_claim) }
  let(:ipf) { create(:in_progress_form) }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:lh_service) { OpenStruct.new(uuid: 'uuid') }
  let(:message_prefix) { "#{described_class} #{Burials::FORM_ID}" }

  describe '#service_name' do
    it 'returns expected name' do
      expect(monitor.send(:service_name)).to eq('burial-application')
    end
  end

  context 'with all params supplied' do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }

    describe '#track_show404' do
      it 'logs a not found error' do
        log = "#{message_prefix} submission not found"
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          claim_id: nil,
          form_id: nil,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :error,
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
        log = "#{message_prefix} fetching submission failed"
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          claim_id: nil,
          form_id: nil,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :error,
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
        log = "#{message_prefix} submission to Sidekiq begun"
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          claim_id: claim.id,
          form_id: claim.form_id,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :info,
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
        log = "#{message_prefix} submission validation error"
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          claim_id: claim.id,
          form_id: claim.form_id,
          errors: [],
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :error,
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
        log = "#{message_prefix} submission to Sidekiq failed"
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          claim_id: claim.id,
          form_id: claim.form_id,
          errors: [],
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :error,
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
        log = "#{message_prefix} submission to Sidekiq success"
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          claim_id: claim.id,
          form_id: claim.form_id,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :info,
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
        log = "#{message_prefix} process attachment error"
        payload = {
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.user_account_uuid,
          in_progress_form_id: ipf.id,
          claim_id: claim.id,
          form_id: claim.form_id,
          errors: [],
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :error,
          log,
          "#{claim_stats_key}.process_attachment_error",
          call_location: anything,
          **payload
        )
        monitor.track_process_attachment_error(ipf, claim, current_user)
      end

      it 'removes bad attachments and updates the in_progress_form' do
        bad_attachment = PersistentAttachment.create!(saved_claim_id: claim.id)

        form_data = {
          death_certificate: [{ 'confirmationCode' => bad_attachment.guid }]
        }
        ipf.update!(form_data: form_data.to_json)

        # Update the claim to have the bad_guid in its attachment_keys and open_struct_form
        allow(claim).to receive_messages(
          attachment_keys: [:deathCertificate],
          open_struct_form: OpenStruct.new(deathCertificate: [OpenStruct.new(confirmationCode: bad_attachment.guid)])
        )

        # Mock file_data to raise an error for this attachment
        allow_any_instance_of(PersistentAttachment).to receive(:file_data).and_raise(StandardError, 'decryption failed')

        # Stub send_email to avoid actual email sending
        allow(monitor).to receive(:send_email)

        expect do
          monitor.track_process_attachment_error(ipf, claim, current_user)
        end.to change { PersistentAttachment.where(id: bad_attachment.id).count }.from(1).to(0)

        # Reload ipf and check that the bad attachment was removed from form_data
        expect(JSON.parse(ipf.form_data)['death_certificate']).to be_empty
      end
    end

    describe '#track_submission_begun' do
      it 'logs sidekiq job started' do
        log = "#{message_prefix} submission to LH begun"
        payload = {
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :info,
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

        log = "#{message_prefix} submission to LH attempted"
        payload = {
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          file: upload[:file],
          attachments: upload[:attachments],
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :info,
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
        log = "#{message_prefix} submission to LH succeeded"
        payload = {
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :info,
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
        log = "#{message_prefix} submission to LH failed, retrying"
        payload = {
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :warn,
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

          log = "#{message_prefix} submission to LH exhausted!"
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
            :error,
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

          log = "#{message_prefix} submission to LH exhausted!"
          payload = {
            confirmation_number: nil,
            user_account_uuid: current_user.uuid,
            form_id: nil,
            claim_id: claim.id, # pulled from msg.args
            message: msg,
            tags: monitor.tags
          }

          expect(Burials::NotificationEmail).not_to receive(:new)
          expect(monitor).to receive(:log_silent_failure).with(payload.compact, current_user.uuid, anything)

          expect(monitor).to receive(:track_request).with(
            :error,
            log,
            "#{submission_stats_key}.exhausted",
            call_location: anything,
            **payload
          )

          monitor.track_submission_exhaustion(msg, nil)
        end
      end
    end

    describe '#track_send_email_failure' do
      it 'logs sidekiq job send_confirmation_email error' do
        log = "#{message_prefix} send_confirmation_email failed"
        payload = {
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :warn,
          log,
          "#{submission_stats_key}.send_confirmation_failed",
          call_location: anything,
          **payload
        )

        monitor.track_send_email_failure(claim, lh_service, current_user.uuid, 'confirmation', monitor_error)
      end

      it 'logs sidekiq job send_submitted_email error' do
        log = "#{message_prefix} send_submitted_email failed"
        payload = {
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          message: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :warn,
          log,
          "#{submission_stats_key}.send_submitted_failed",
          call_location: anything,
          **payload
        )

        monitor.track_send_email_failure(claim, lh_service, current_user.uuid, 'submitted', monitor_error)
      end
    end

    describe '#track_file_cleanup_error' do
      it 'logs sidekiq job ensure file cleanup error' do
        log = "#{message_prefix} cleanup failed"
        payload = {
          claim_id: claim.id,
          form_id: claim.form_id,
          benefits_intake_uuid: lh_service.uuid,
          confirmation_number: claim.confirmation_number,
          user_account_uuid: current_user.uuid,
          error: monitor_error.message,
          tags: monitor.tags
        }

        expect(monitor).to receive(:track_request).with(
          :error,
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
