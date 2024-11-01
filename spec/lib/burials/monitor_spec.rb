# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/burials/monitor'

RSpec.describe Burials::Monitor do
  let(:monitor) { described_class.new }
  let(:claim) { create(:burial_claim_v2) }
  let(:ipf) { create(:in_progress_form) }

  context 'with all params supplied' do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }

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
  end
end
