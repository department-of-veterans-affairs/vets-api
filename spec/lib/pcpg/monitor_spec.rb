# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/pcpg/monitor'

RSpec.describe PCPG::Monitor do
  let(:monitor) { described_class.new }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:benefits_intake_submission_stats_key) { described_class::BENEFITS_INTAKE_SUBMISSION_STATS_KEY }
  let(:claim) { create(:education_career_counseling_claim) }
  let(:ipf) { create(:in_progress_form) }

  context 'with all params supplied' do
    let(:current_user) { create(:user) }
    let(:monitor_error) { create(:monitor_error) }
    let(:lh_service) { OpenStruct.new(uuid: 'uuid') }

    describe '#track_submission_exhaustion' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, current_user.uuid], error_message: 'Error!' }

        log = "Failed all retries on SubmitCareerCounselingJob, last error: #{msg['error_message']}"
        payload = {
          form_id: claim.form_id,
          claim_id: claim.id,
          confirmation_number: claim.confirmation_number,
          message: msg
        }

        expect(monitor).to receive(:log_silent_failure_no_confirmation).with(payload, current_user.uuid, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
        expect(Rails.logger).to receive(:error).with(log, user_uuid: current_user.uuid, **payload)

        monitor.track_submission_exhaustion(msg, claim, claim.parsed_form.dig('claimantInformation', 'emailAddress'))
      end

      it 'logs with no claim information if claim is passed in as nil' do
        msg = { 'args' => [claim.id, current_user.uuid], error_message: 'Error!' }

        log = "Failed all retries on SubmitCareerCounselingJob, last error: #{msg['error_message']}"
        payload = {
          form_id: nil,
          claim_id: msg['args'].first,
          confirmation_number: nil,
          message: msg
        }

        expect(monitor).to receive(:log_silent_failure).with(payload, current_user.uuid, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
        expect(Rails.logger).to receive(:error).with(log, user_uuid: current_user.uuid, **payload)

        monitor.track_submission_exhaustion(msg, nil, nil)
      end
    end

    describe '#track_benefits_intake_submission_exhaustion' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, current_user.uuid] }

        log = 'Lighthouse::SubmitBenefitsIntakeClaim PCPG 28-8832 submission to LH exhausted!'
        payload = {
          form_id: claim.form_id,
          claim_id: claim.id,
          confirmation_number: claim.confirmation_number,
          message: msg
        }

        expect(monitor).to receive(:log_silent_failure_no_confirmation).with(payload, current_user.uuid, anything)
        expect(StatsD).to receive(:increment).with("#{benefits_intake_submission_stats_key}.exhausted")
        expect(Rails.logger).to receive(:error).with(log, user_uuid: current_user.uuid, **payload)
        email_address = claim.parsed_form.dig('claimantInformation', 'emailAddress')
        monitor.track_benefits_intake_submission_exhaustion(msg, claim, email_address)
      end

      it 'logs sidekiq job exhaustion without email' do
        msg = { 'args' => [claim.id, current_user.uuid] }

        log = 'Lighthouse::SubmitBenefitsIntakeClaim PCPG 28-8832 submission to LH exhausted!'
        payload = {
          form_id: claim.form_id,
          claim_id: claim.id,
          confirmation_number: claim.confirmation_number,
          message: msg
        }

        expect(monitor).to receive(:log_silent_failure).with(payload, current_user.uuid, anything)
        expect(StatsD).to receive(:increment).with("#{benefits_intake_submission_stats_key}.exhausted")
        expect(Rails.logger).to receive(:error).with(log, user_uuid: current_user.uuid, **payload)

        monitor.track_benefits_intake_submission_exhaustion(msg, claim, nil)
      end
    end
  end
end
