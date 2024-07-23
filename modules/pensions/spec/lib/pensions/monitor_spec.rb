# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/pensions/monitor'

RSpec.describe Pensions::Monitor do
  let(:monitor) { described_class.new }
  let(:stats_key) { described_class::CLAIM_STATS_KEY }
  let(:claim) { create(:pensions_module_pension_claim) }
  let(:ipf) { create(:in_progress_form) }

  context "with all params supplied" do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }

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
          user_uuid: current_user.uuid,
        }

        expect(StatsD).to receive(:increment).with("#{stats_key}.attempt")
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

        expect(StatsD).to receive(:increment).with("#{stats_key}.failure")
        expect(Rails.logger).to receive(:error).with(log, payload)

        monitor.track_create_error(ipf, claim, current_user, monitor_error)
      end
    end

  end
end
