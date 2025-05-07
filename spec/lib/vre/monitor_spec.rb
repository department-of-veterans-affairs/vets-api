# frozen_string_literal: true

require 'rails_helper'
require 'vre/monitor'

RSpec.describe VRE::Monitor do
  let(:monitor) { described_class.new }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:claim) { create(:veteran_readiness_employment_claim) }

  let(:user_struct) do
    OpenStruct.new(
      edipi: '1007697216',
      birls_id: '796043735',
      participant_id: '600061742',
      pid: '600061742',
      birth_date: '1986-05-06T00:00:00+00:00'.to_date,
      ssn: '796043735',
      vet360_id: '1781151',
      loa3?: true,
      icn: '1013032368V065534',
      uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
      va_profile_email: 'test@test.com'
    )
  end
  let(:encrypted_user) { KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json) }

  describe '#track_submission_exhaustion' do
    it 'logs sidekiq job exhaustion failure avoided' do
      msg = { 'args' => [claim.id, encrypted_user], error_message: 'Error!' }

      log = "Failed all retries on VRE::Submit1900Job, last error: #{msg['error_message']}"
      payload = {
        message: msg
      }

      expect(monitor).to receive(:log_silent_failure_no_confirmation).with(payload, nil, anything)
      expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
      expect(Rails.logger).to receive(:error).with(log)

      monitor.track_submission_exhaustion(msg, user_struct.va_profile_email)
    end

    it 'logs sidekiq job exhaustion failure' do
      msg = { 'args' => [claim.id, encrypted_user], error_message: 'Error!' }

      log = "Failed all retries on VRE::Submit1900Job, last error: #{msg['error_message']}"
      payload = {
        message: msg
      }

      expect(monitor).to receive(:log_silent_failure).with(payload, nil, anything)
      expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted")
      expect(Rails.logger).to receive(:error).with(log)

      monitor.track_submission_exhaustion(msg, nil)
    end
  end
end
