# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/burials/monitor'

RSpec.describe Burials::Monitor do
  let(:monitor) { described_class.new }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
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
          user_uuid: current_user.uuid
        }

        expect(StatsD).to receive(:increment).with("#{claim_stats_key}.attempt")
        expect(Rails.logger).to receive(:info).with(log, payload)

        monitor.track_create_attempt(claim, current_user)
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
          message: monitor_error.message
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
  end
end
