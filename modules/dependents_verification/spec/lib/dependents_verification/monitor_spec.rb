# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsVerification::Monitor do
  let(:monitor) { described_class.new }
  let(:claim) { create(:dependents_verification_claim) }
  let(:ipf) { create(:in_progress_form) }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:message_prefix) { "#{described_class} #{DependentsVerification::FORM_ID}" }

  describe '#service_name' do
    it 'returns expected name' do
      expect(monitor.send(:service_name)).to eq('dependents-verification')
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
    end
  end
end
