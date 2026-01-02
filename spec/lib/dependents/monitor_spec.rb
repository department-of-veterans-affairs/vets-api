# frozen_string_literal: true

require 'rails_helper'
require 'dependents/monitor'

RSpec.describe Dependents::Monitor do
  # Performance tweak
  before do
    allow(PdfFill::Filler)
      .to receive(:fill_form) { |saved_claim, *_|
        "tmp/pdfs/686C-674_#{saved_claim.id || 'stub'}_final.pdf"
      }
  end

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
      let(:tags) { ['form_id:686C-674', 'service:dependents-application', 'v2:false'] }

      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim.id, encrypted_vet_info, encrypted_user], error_message: 'Error!' }

        log = 'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
              "last error: #{msg['error_message']}"
        payload = {
          claim:,
          error: msg,
          service: 'dependents-application',
          tags:,
          use_v2: false,
          user_account_uuid: nil
        }

        expect(monitor_v1).to receive(:log_silent_failure).with(payload, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted", tags:)
        expect(Rails.logger).to receive(:error).with(log)

        monitor_v1.track_submission_exhaustion(msg)
      end

      it 'logs sidekiq job exhaustion with failure avoided' do
        msg = { 'args' => [claim.id, encrypted_vet_info, encrypted_user], error_message: 'Error!' }

        log = 'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
              "last error: #{msg['error_message']}"
        payload = {
          claim:,
          error: msg,
          service: 'dependents-application',
          tags:,
          use_v2: false,
          user_account_uuid: nil
        }

        expect(monitor_v1).to receive(:log_silent_failure_avoided).with(payload, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted", tags:)
        expect(Rails.logger).to receive(:error).with(log)

        monitor_v1.track_submission_exhaustion(msg, user_struct.va_profile_email)
      end
    end

    describe '#track_event' do
      let(:tags) { ['service:dependents-application', 'function:track_event', 'form_id:686C-674', 'v2:false'] }

      it 'handles an error' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).once
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).twice
        expect(StatsD).to receive(:increment).with('test.monitor.exhaustion', tags:)
        expect(Rails.logger).to receive(:error).with('Error!', {
                                                       context: {
                                                         claim_id: claim.id,
                                                         confirmation_number: claim.confirmation_number,
                                                         error: 'test',
                                                         form_id: '686C-674',
                                                         service: 'dependents-application',
                                                         tags: ['form_id:686C-674', 'service:dependents-application',
                                                                'v2:false'],
                                                         use_v2: false,
                                                         user_account_uuid: nil
                                                       },
                                                       file: a_kind_of(String),
                                                       function: 'track_event',
                                                       line: a_kind_of(Integer),
                                                       service: 'dependents-application',
                                                       statsd: 'test.monitor.exhaustion'
                                                     })

        monitor_v1.track_event('error', 'Error!', 'test.monitor.exhaustion', error: 'test')
      end

      it 'handles an info log' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).once
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).twice
        expect(StatsD).to receive(:increment).with('test.monitor.success', tags:)
        expect(Rails.logger).to receive(:info).with('Success!', {
                                                      context: {
                                                        claim_id: claim.id,
                                                        confirmation_number: claim.confirmation_number,
                                                        error: 'test',
                                                        form_id: '686C-674',
                                                        service: 'dependents-application',
                                                        tags: ['form_id:686C-674', 'service:dependents-application',
                                                               'v2:false'],
                                                        use_v2: false,
                                                        user_account_uuid: nil
                                                      },
                                                      file: a_kind_of(String),
                                                      function: 'track_event',
                                                      line: a_kind_of(Integer),
                                                      service: 'dependents-application',
                                                      statsd: 'test.monitor.success'
                                                    })

        monitor_v1.track_event('info', 'Success!', 'test.monitor.success', error: 'test')
      end

      it 'handles a warning' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).once
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).twice
        expect(StatsD).to receive(:increment).with('test.monitor.failure', tags:)
        expect(Rails.logger).to receive(:warn).with('Oops!', {
                                                      context: {
                                                        claim_id: claim.id,
                                                        confirmation_number: claim.confirmation_number,
                                                        error: 'test',
                                                        form_id: '686C-674',
                                                        service: 'dependents-application',
                                                        tags: ['form_id:686C-674', 'service:dependents-application',
                                                               'v2:false'],
                                                        use_v2: false,
                                                        user_account_uuid: nil
                                                      },
                                                      file: a_kind_of(String),
                                                      function: 'track_event',
                                                      line: a_kind_of(Integer),
                                                      service: 'dependents-application',
                                                      statsd: 'test.monitor.failure'
                                                    })

        monitor_v1.track_event('warn', 'Oops!', 'test.monitor.failure', error: 'test')
      end

      it 'logs an error when it fails' do
        allow(monitor_v1).to receive(:submit_event).and_raise(StandardError.new('test error'))

        expect(Rails.logger)
          .to receive(:error)
          .with(
            'Dependents::Monitor#track_event error',
            {
              level: 'info',
              message: 'test error',
              stats_key: 'test.monitor.error',
              payload: hash_including(error: 'test error'),
              error: 'test error'
            }
          )

        monitor_v1.track_event('info', 'test error', 'test.monitor.error', { error: 'test error' })
      end
    end
  end

  context 'v2' do
    describe '#track_submission_exhaustion' do
      let(:tags) { ['form_id:686C-674-V2', 'service:dependents-application', 'v2:true'] }

      it 'logs sidekiq job exhaustion' do
        msg = { 'args' => [claim_v2.id, encrypted_vet_info, encrypted_user], error_message: 'Error!' }

        log = 'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
              "last error: #{msg['error_message']}"
        payload = {
          claim: claim_v2,
          error: msg,
          service: 'dependents-application',
          tags:,
          use_v2: true,
          user_account_uuid: nil
        }

        expect(monitor_v2).to receive(:log_silent_failure).with(payload, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted", tags:)
        expect(Rails.logger).to receive(:error).with(log)

        monitor_v2.track_submission_exhaustion(msg)
      end

      it 'logs sidekiq job exhaustion with failure avoided' do
        msg = { 'args' => [claim_v2.id, encrypted_vet_info, encrypted_user], error_message: 'Error!' }

        log = 'Failed all retries on Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, ' \
              "last error: #{msg['error_message']}"
        payload = {
          claim: claim_v2,
          error: msg,
          service: 'dependents-application',
          tags: ['form_id:686C-674-V2', 'service:dependents-application', 'v2:true'],
          use_v2: true,
          user_account_uuid: nil
        }

        expect(monitor_v2).to receive(:log_silent_failure_avoided).with(payload, anything)
        expect(StatsD).to receive(:increment).with("#{submission_stats_key}.exhausted", tags:)
        expect(Rails.logger).to receive(:error).with(log)

        monitor_v2.track_submission_exhaustion(msg, user_struct.va_profile_email)
      end
    end

    describe '#track_event' do
      let(:tags) { ['service:dependents-application', 'function:track_event', 'form_id:686C-674-V2', 'v2:true'] }

      it 'handles an error' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.exhaustion', tags:)
        expect(Rails.logger).to receive(:error).with('Error!', {
                                                       context: {
                                                         claim_id: claim_v2.id,
                                                         confirmation_number: claim_v2.confirmation_number,
                                                         error: 'test',
                                                         form_id: '686C-674-V2',
                                                         service: 'dependents-application',
                                                         tags: ['form_id:686C-674-V2',
                                                                'service:dependents-application', 'v2:true'],
                                                         use_v2: true,
                                                         user_account_uuid: nil
                                                       },
                                                       file: a_kind_of(String),
                                                       function: 'track_event',
                                                       line: a_kind_of(Integer),
                                                       service: 'dependents-application',
                                                       statsd: 'test.monitor.exhaustion'
                                                     })

        monitor_v2.track_event('error', 'Error!', 'test.monitor.exhaustion', error: 'test')
      end

      it 'handles an info log' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.success', tags:)
        expect(Rails.logger).to receive(:info).with('Success!', {
                                                      context: {
                                                        claim_id: claim_v2.id,
                                                        confirmation_number: claim_v2.confirmation_number,
                                                        error: 'test',
                                                        form_id: '686C-674-V2',
                                                        service: 'dependents-application',
                                                        tags: ['form_id:686C-674-V2', 'service:dependents-application',
                                                               'v2:true'],
                                                        use_v2: true,
                                                        user_account_uuid: nil
                                                      },
                                                      file: a_kind_of(String),
                                                      function: 'track_event',
                                                      line: a_kind_of(Integer),
                                                      service: 'dependents-application',
                                                      statsd: 'test.monitor.success'
                                                    })

        monitor_v2.track_event('info', 'Success!', 'test.monitor.success', error: 'test')
      end

      it 'handles a warning' do
        expect(StatsD).to receive(:increment).with('saved_claim.create', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('saved_claim.pdf.overflow', anything).at_least(:once)
        expect(StatsD).to receive(:increment).with('test.monitor.failure', tags:)
        expect(Rails.logger).to receive(:warn).with('Oops!', {
                                                      context: {
                                                        claim_id: claim_v2.id,
                                                        confirmation_number: claim_v2.confirmation_number,
                                                        error: 'test',
                                                        form_id: '686C-674-V2',
                                                        service: 'dependents-application',
                                                        tags: ['form_id:686C-674-V2', 'service:dependents-application',
                                                               'v2:true'],
                                                        use_v2: true,
                                                        user_account_uuid: nil
                                                      },
                                                      file: a_kind_of(String),
                                                      function: 'track_event',
                                                      line: a_kind_of(Integer),
                                                      service: 'dependents-application',
                                                      statsd: 'test.monitor.failure'
                                                    })

        monitor_v2.track_event('warn', 'Oops!', 'test.monitor.failure', error: 'test')
      end
    end
  end

  context 'version independent' do
    describe '#track_unknown_claim_type' do
      it 'logs unknown claim type error' do
        error = StandardError.new('Unknown type')
        metric = "#{described_class::EMAIL_STATS_KEY}.unknown_type"
        tags = ['form_id:686C-674', 'service:dependents-application', 'v2:false']
        payload = {
          claim:,
          service: 'dependents-application',
          tags:,
          use_v2: false,
          user_account_uuid: nil,
          statsd: metric,
          e: error
        }

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:error).with("Unknown Dependents form type for claim #{claim.id}", payload)

        monitor_v1.track_unknown_claim_type(error)
      end
    end

    describe '#track_send_email_success' do
      it 'logs email success' do
        message = 'Email sent successfully'
        metric = 'test.email.success'
        user_account_id = 'user123'
        tags = ['form_id:686C-674', 'service:dependents-application', 'v2:false']
        payload = {
          claim:,
          service: 'dependents-application',
          tags:,
          use_v2: false,
          user_account_uuid: nil,
          statsd: metric,
          user_account_id:
        }

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:info).with(message, payload)

        monitor_v1.track_send_email_success(message, metric, user_account_id)
      end
    end

    describe '#track_send_email_error' do
      it 'logs email error' do
        message = 'Email failed to send'
        metric = 'test.email.error'
        error = StandardError.new('SMTP error')
        user_account_uuid = 'uuid123'
        tags = ['form_id:686C-674', 'service:dependents-application', 'v2:false']
        payload = {
          claim:,
          service: 'dependents-application',
          tags:,
          use_v2: false,
          user_account_uuid:,
          statsd: metric,
          e: error
        }

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:error).with(message, payload)

        monitor_v1.track_send_email_error(message, metric, error, user_account_uuid)
      end
    end

    describe '#track_send_submitted_email_success' do
      it 'tracks submitted email success' do
        user_account_uuid = 'uuid123'
        message = "'Submitted' email success for claim #{claim.id}"
        metric = "#{described_class::EMAIL_STATS_KEY}.submitted.success"

        expect(monitor_v1).to receive(:track_send_email_success).with(message, metric, user_account_uuid)

        monitor_v1.track_send_submitted_email_success(user_account_uuid)
      end
    end

    describe '#track_send_submitted_email_failure' do
      it 'tracks submitted email failure' do
        error = StandardError.new('Email error')
        user_account_uuid = 'uuid123'
        message = "'Submitted' email failure for claim #{claim.id}"
        metric = "#{described_class::EMAIL_STATS_KEY}.submitted.failure"

        expect(monitor_v1).to receive(:track_send_email_error).with(message, metric, error, user_account_uuid)

        monitor_v1.track_send_submitted_email_failure(error, user_account_uuid)
      end
    end

    describe '#track_send_received_email_success' do
      it 'tracks received email success' do
        user_account_uuid = 'uuid123'
        message = "'Received' email success for claim #{claim.id}"
        metric = "#{described_class::EMAIL_STATS_KEY}.received.success"

        expect(monitor_v1).to receive(:track_send_email_success).with(message, metric, user_account_uuid)

        monitor_v1.track_send_received_email_success(user_account_uuid)
      end
    end

    describe '#track_send_received_email_failure' do
      it 'tracks received email failure' do
        error = StandardError.new('Email error')
        user_account_uuid = 'uuid123'

        expect(monitor_v1)
          .to receive(:track_send_email_failure)
          .with(claim, nil, user_account_uuid, 'submitted', error)

        monitor_v1.track_send_received_email_failure(error, user_account_uuid)
      end
    end

    describe '#track_pdf_upload_error' do
      it 'tracks PDF upload error' do
        metric = "#{described_class::CLAIM_STATS_KEY}.upload_pdf.failure"
        payload = {
          claim:,
          service: 'dependents-application',
          tags: ['form_id:686C-674', 'service:dependents-application', 'v2:false'],
          use_v2: false,
          user_account_uuid: nil,
          statsd: metric
        }

        expect(monitor_v1)
          .to receive(:track_event)
          .with('error', 'DependencyClaim error in upload_to_vbms method', metric, payload)

        monitor_v1.track_pdf_upload_error
      end
    end

    describe '#track_to_pdf_failure' do
      it 'tracks PDF generation failure' do
        error = StandardError.new('PDF error')
        form_id = '686C-674'
        metric = "#{described_class::CLAIM_STATS_KEY}.to_pdf.failure"
        tags = ['form_id:686C-674', 'service:dependents-application', 'v2:false']
        payload = {
          claim:,
          service: 'dependents-application',
          tags:,
          use_v2: false,
          user_account_uuid: nil,
          statsd: metric,
          e: error,
          form_id:
        }

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:error).with('SavedClaim::DependencyClaim#to_pdf error', payload)

        monitor_v1.track_to_pdf_failure(error, form_id)
      end
    end

    describe '#track_pdf_overflow_tracking_failure' do
      it 'tracks PDF overflow tracking failure' do
        error = StandardError.new('Overflow tracking error')
        metric = "#{described_class::CLAIM_STATS_KEY}.track_pdf_overflow.failure"
        tags = ['form_id:686C-674', 'service:dependents-application', 'v2:false']
        payload = {
          claim:,
          service: 'dependents-application',
          tags:,
          use_v2: false,
          user_account_uuid: nil,
          statsd: metric,
          e: error
        }

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:warn).with('Error tracking PDF overflow', payload)

        monitor_v1.track_pdf_overflow_tracking_failure(error)
      end
    end

    describe '#track_pdf_overflow' do
      it 'tracks PDF overflow' do
        form_id = '686C-674'
        metric = 'saved_claim.pdf.overflow'

        # Allow any StatsD calls to happen for test setup or the test will fail
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:increment).with(metric, tags: ["form_id:#{form_id}"])

        monitor_v1.track_pdf_overflow(form_id)
      end
    end

    describe '#track_pension_related_submission' do
      it 'tracks pension related submission with correct tags' do
        form_id = '686C-674-V2'
        metric = "#{described_class::PENSION_SUBMISSION_STATS_KEY}.686c-674.submitted"

        # Allow any StatsD calls to happen for test setup or the test will fail
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:increment).with(metric, tags: ["form_id:#{form_id}"])

        monitor_v2.track_pension_related_submission(form_id:, form_type: '686c-674')
      end
    end

    describe '#claim' do
      context 'when claim is not found' do
        it 'logs warning and returns nil' do
          allow(SavedClaim::DependencyClaim).to receive(:find).and_raise(ActiveRecord::RecordNotFound)

          expect(Rails.logger).to receive(:warn).with(
            'Unable to find claim for Dependents::Monitor',
            { claim_id: claim.id, e: ActiveRecord::RecordNotFound }
          ).at_least(:once)

          result = monitor_v1.send(:claim, claim.id)
          expect(result).to be_nil
        end
      end
    end

    describe '#form_id' do
      it 'returns the form ID' do
        expect(monitor_v1.send(:form_id)).to eq('686C-674')
      end
    end

    describe '#submission_stats_key' do
      it 'returns the submission stats key' do
        expect(monitor_v1.send(:submission_stats_key)).to eq('worker.submit_686c_674_backup_submission')
      end
    end
  end
end
