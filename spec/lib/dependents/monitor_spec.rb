# frozen_string_literal: true

require 'rails_helper'
require 'dependents/monitor'

RSpec.describe Dependents::Monitor do
  let(:claim) { create(:dependency_claim) }
  let(:claim_v2) { create(:dependency_claim_v2) }
  let(:monitor_v1) { described_class.new(claim.id) }
  let(:monitor_v2) { described_class.new(claim_v2.id) }
  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
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

    describe '#track_event' do
      let(:tags) { { tags: ['service:dependents-application', 'function:track_event', 'v2:false'] } }

      it 'handles an error' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.exhaustion', tags)
        expect(Rails.logger).to receive(:error).with('Error!', {
                                                       context: {
                                                         claim_id: claim.id,
                                                         confirmation_number: claim.confirmation_number,
                                                         extra: 'test',
                                                         form_id: '686C-674',
                                                         service: 'dependents-application',
                                                         tags: ['service:dependents-application', 'v2:false'],
                                                         use_v2: false,
                                                         user_account_uuid: nil
                                                       },
                                                       file: a_kind_of(String),
                                                       function: 'track_event',
                                                       line: a_kind_of(Integer),
                                                       service: 'dependents-application',
                                                       statsd: 'test.monitor.exhaustion'
                                                     })

        monitor_v1.track_event('error', 'Error!', 'test.monitor.exhaustion', { extra: 'test' })
      end

      it 'handles an info log' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.success', tags)
        expect(Rails.logger).to receive(:info).with('Success!', {
                                                      context: {
                                                        claim_id: claim.id,
                                                        confirmation_number: claim.confirmation_number,
                                                        extra: 'test',
                                                        form_id: '686C-674',
                                                        service: 'dependents-application',
                                                        tags: ['service:dependents-application', 'v2:false'],
                                                        use_v2: false,
                                                        user_account_uuid: nil
                                                      },
                                                      file: a_kind_of(String),
                                                      function: 'track_event',
                                                      line: a_kind_of(Integer),
                                                      service: 'dependents-application',
                                                      statsd: 'test.monitor.success'
                                                    })

        monitor_v1.track_event('info', 'Success!', 'test.monitor.success', { extra: 'test' })
      end

      it 'handles a warning' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.failure', tags)
        expect(Rails.logger).to receive(:warn).with('Oops!', {
                                                      context: {
                                                        claim_id: claim.id,
                                                        confirmation_number: claim.confirmation_number,
                                                        extra: 'test',
                                                        form_id: '686C-674',
                                                        service: 'dependents-application',
                                                        tags: ['service:dependents-application', 'v2:false'],
                                                        use_v2: false,
                                                        user_account_uuid: nil
                                                      },
                                                      file: a_kind_of(String),
                                                      function: 'track_event',
                                                      line: a_kind_of(Integer),
                                                      service: 'dependents-application',
                                                      statsd: 'test.monitor.failure'
                                                    })

        monitor_v1.track_event('warn', 'Oops!', 'test.monitor.failure', { extra: 'test' })
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

    describe '#track_event' do
      let(:tags) { { tags: ['service:dependents-application', 'function:track_event', 'v2:true'] } }

      it 'handles an error' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.exhaustion', tags)
        expect(Rails.logger).to receive(:error).with('Error!', {
                                                       context: {
                                                         claim_id: claim_v2.id,
                                                         confirmation_number: claim_v2.confirmation_number,
                                                         extra: 'test',
                                                         form_id: '686C-674-V2',
                                                         service: 'dependents-application',
                                                         tags: ['service:dependents-application', 'v2:true'],
                                                         use_v2: true,
                                                         user_account_uuid: nil
                                                       },
                                                       file: a_kind_of(String),
                                                       function: 'track_event',
                                                       line: a_kind_of(Integer),
                                                       service: 'dependents-application',
                                                       statsd: 'test.monitor.exhaustion'
                                                     })

        monitor_v2.track_event('error', 'Error!', 'test.monitor.exhaustion', { extra: 'test' })
      end

      it 'handles an info log' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.success', tags)
        expect(Rails.logger).to receive(:info).with('Success!', {
                                                      context: {
                                                        claim_id: claim_v2.id,
                                                        confirmation_number: claim_v2.confirmation_number,
                                                        extra: 'test',
                                                        form_id: '686C-674-V2',
                                                        service: 'dependents-application',
                                                        tags: ['service:dependents-application', 'v2:true'],
                                                        use_v2: true,
                                                        user_account_uuid: nil
                                                      },
                                                      file: a_kind_of(String),
                                                      function: 'track_event',
                                                      line: a_kind_of(Integer),
                                                      service: 'dependents-application',
                                                      statsd: 'test.monitor.success'
                                                    })

        monitor_v2.track_event('info', 'Success!', 'test.monitor.success', { extra: 'test' })
      end

      it 'handles a warning' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.failure', tags)
        expect(Rails.logger).to receive(:warn).with('Oops!', {
                                                      context: {
                                                        claim_id: claim_v2.id,
                                                        confirmation_number: claim_v2.confirmation_number,
                                                        extra: 'test',
                                                        form_id: '686C-674-V2',
                                                        service: 'dependents-application',
                                                        tags: ['service:dependents-application', 'v2:true'],
                                                        use_v2: true,
                                                        user_account_uuid: nil
                                                      },
                                                      file: a_kind_of(String),
                                                      function: 'track_event',
                                                      line: a_kind_of(Integer),
                                                      service: 'dependents-application',
                                                      statsd: 'test.monitor.failure'
                                                    })

        monitor_v2.track_event('warn', 'Oops!', 'test.monitor.failure', { extra: 'test' })
      end
    end
  end
end
