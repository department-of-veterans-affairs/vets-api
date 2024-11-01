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
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_show404(claim.confirmation_number, current_user, monitor_error)
      end
    end

    describe '#track_show_error' do
      it 'logs a submission failed error' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_show_error(claim.confirmation_number, current_user, monitor_error)
      end
    end

    describe '#track_create_attempt' do
      it 'logs sidekiq started' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_create_attempt(claim, current_user)
      end
    end

    describe '#track_create_validation_error' do
      it 'logs create failed' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_create_validation_error(ipf, claim, current_user)
      end
    end

    describe '#track_process_attachment_error' do
      it 'logs process attachment failed' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_process_attachment_error(ipf, claim, current_user)
      end
    end

    describe '#track_create_error' do
      it 'logs sidekiq failed' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_create_error(ipf, claim, current_user, monitor_error)
      end
    end

    describe '#track_create_success' do
      it 'logs sidekiq success' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_create_success(ipf, claim, current_user)
      end
    end

    describe '#track_submission_begun' do
      it 'logs sidekiq job started' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_submission_begun(claim, lh_service, current_user.uuid)
      end
    end

    describe '#track_submission_attempted' do
      it 'logs sidekiq job upload attempt' do
        upload = {
          file: 'pdf-file-path',
          attachments: %w[pdf-attachment1 pdf-attachment2]
        }

        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_submission_attempted(claim, lh_service, current_user.uuid, upload)
      end
    end

    describe '#track_submission_success' do
      it 'logs sidekiq job successful' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_submission_success(claim, lh_service, current_user.uuid)
      end
    end

    describe '#track_submission_retry' do
      it 'logs sidekiq job failure and retry' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_submission_retry(claim, lh_service, current_user.uuid, monitor_error)
      end
    end

    describe '#track_submission_exhaustion' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, current_user.uuid] }
        payload = {
          form_id: claim.form_id,
          user_uuid: current_user.uuid,
          claim_id: claim.id,
          confirmation_number: claim.confirmation_number,
          message: msg
        }

        expect(monitor).to receive(:log_silent_failure).with(payload, current_user.uuid, anything)
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_submission_exhaustion(msg, claim)
      end
    end

    describe '#track_send_confirmation_email_failure' do
      it 'logs sidekiq job send_confirmation_email error' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_send_confirmation_email_failure(claim, lh_service, current_user.uuid, monitor_error)
      end
    end

    describe '#track_file_cleanup_error' do
      it 'logs sidekiq job ensure file cleanup error' do
        expect_any_instance_of(Logging::Monitor).to receive(:track_request)
        monitor.track_file_cleanup_error(claim, lh_service, current_user.uuid, monitor_error)
      end
    end
  end
end
