# frozen_string_literal: true

require 'rails_helper'
require 'dependents/monitor'

RSpec.describe Dependents::Monitor do
  let(:monitor_v1) { described_class.new(false) }
  let(:monitor_v2) { described_class.new(true) }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:claim) { create(:dependency_claim) }
  let(:user) { create(:evss_user, :loa3) }

  let(:vet_info) do
    {
      'veteran_information' => {
        'full_name' => {
          'first' => 'Mark', 'middle' => 'A', 'last' => 'Webb'
        },
        'common_name' => 'Mark',
        'participant_id' => '600061742',
        'uuid' => user.uuid,
        'email' => 'vets.gov.user+228@gmail.com',
        'va_profile_email' => 'vets.gov.user+228@gmail.com',
        'ssn' => '796104437',
        'va_file_number' => '796104437',
        'icn' => user.icn,
        'birth_date' => '1950-10-04'
      }
    }
  end
  let(:encrypted_vet_info) { KmsEncrypted::Box.new.encrypt(vet_info.to_json) }
  let(:central_mail_submission) { claim.central_mail_submission }

  let(:user_struct) do
    OpenStruct.new(
      first_name: vet_info['veteran_information']['full_name']['first'],
      last_name: vet_info['veteran_information']['full_name']['last'],
      middle_name: vet_info['veteran_information']['full_name']['middle'],
      ssn: vet_info['veteran_information']['ssn'],
      email: vet_info['veteran_information']['email'],
      va_profile_email: vet_info['veteran_information']['va_profile_email'],
      participant_id: vet_info['veteran_information']['participant_id'],
      icn: vet_info['veteran_information']['icn'],
      uuid: vet_info['veteran_information']['uuid'],
      common_name: vet_info['veteran_information']['common_name']
    )
  end
  let(:encrypted_user) { KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json) }

  context 'v1' do
    describe '#track_submission_exhaustion' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, encrypted_vet_info, encrypted_user], error_message: 'Error!' }

        log = 'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
              "last error: #{msg['error_message']}"
        payload = {
          message: msg
        }
        tags = { tags: ['service:dependents-application', 'v2:false'] }

        expect(monitor_v1).to receive(:log_silent_failure).with(payload, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted", tags)
        expect(Rails.logger).to receive(:error).with(log)

        monitor_v1.track_submission_exhaustion(msg)
      end

      it 'logs sidekiq job exhaustion with failure avoided' do
        msg = { 'args' => [claim.id, encrypted_vet_info, encrypted_user], error_message: 'Error!' }

        log = 'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
              "last error: #{msg['error_message']}"
        payload = {
          message: msg
        }
        tags = { tags: ['service:dependents-application', 'v2:false'] }

        expect(monitor_v1).to receive(:log_silent_failure_no_confirmation).with(payload, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted", tags)
        expect(Rails.logger).to receive(:error).with(log)

        monitor_v1.track_submission_exhaustion(msg, user_struct.va_profile_email)
      end
    end
  end

  context 'v2' do
    describe '#track_submission_exhaustion' do
      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, encrypted_vet_info, encrypted_user], error_message: 'Error!' }

        log = 'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
              "last error: #{msg['error_message']}"
        payload = {
          message: msg
        }

        expect(monitor_v2).to receive(:log_silent_failure).with(payload, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted",
                                                   { tags: ['service:dependents-application', 'v2:true'] })
        expect(Rails.logger).to receive(:error).with(log)

        monitor_v2.track_submission_exhaustion(msg)
      end

      it 'logs sidekiq job exhaustion with failure avoided' do
        msg = { 'args' => [claim.id, encrypted_vet_info, encrypted_user], error_message: 'Error!' }

        log = 'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
              "last error: #{msg['error_message']}"
        payload = {
          message: msg
        }

        expect(monitor_v2).to receive(:log_silent_failure_no_confirmation).with(payload, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted",
                                                   { tags: ['service:dependents-application', 'v2:true'] })
        expect(Rails.logger).to receive(:error).with(log)

        monitor_v2.track_submission_exhaustion(msg, user_struct.va_profile_email)
      end
    end
  end
end
