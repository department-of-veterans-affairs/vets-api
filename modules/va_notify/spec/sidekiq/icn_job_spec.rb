# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe VANotify::IcnJob, type: :worker do
  let(:icn) { '1013062086V794840' }
  let(:template_id) { 'template_id' }

  before do
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')

    allow(Settings.vanotify.services.va_gov).to receive(:api_key).and_return(
      'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    )
  end

  describe '#perform' do
    it 'sends an email using the template id' do
      client = double
      expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.va_gov.api_key).and_return(client)

      expect(client).to receive(:send_email).with(
        {
          recipient_identifier: {
            id_value: icn,
            id_type: 'ICN'
          },
          template_id:
        }
      )

      expect(StatsD).to receive(:increment).with('api.vanotify.icn_job.success')

      described_class.new.perform(icn, template_id)
    end

    it 'can use non-default api key' do
      client = double
      api_key = 'test-yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy-zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz'
      expect(VaNotify::Service).to receive(:new).with(api_key).and_return(client)

      expect(client).to receive(:send_email).with(
        {
          recipient_identifier: {
            id_value: icn,
            id_type: 'ICN'
          },
          template_id:,
          personalisation: {}
        }
      )
      personalization = {}

      described_class.new.perform(icn, template_id, personalization, api_key)
    end

    context 'when vanotify returns a 400 error' do
      it 'rescues and logs the error' do
        VCR.use_cassette('va_notify/bad_request') do
          job = described_class.new
          expect(job).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Exceptions::BackendServiceException),
            {
              args: {
                recipient_identifier: {
                  id_value: icn,
                  id_type: 'ICN'
                },
                template_id:,
                personalisation: nil
              }
            },
            {
              error: :va_notify_icn_job
            }
          )

          job.perform(icn, template_id)
        end
      end
    end
  end

  describe 'when job has failed' do
    let(:error) { RuntimeError.new('an error occurred!') }
    let(:msg) do
      {
        'jid' => 123,
        'class' => described_class.to_s,
        'error_class' => 'RuntimeError',
        'error_message' => 'an error occurred!'
      }
    end

    it 'logs an error to the Rails console and increments StatsD counter' do
      expect(Rails.logger).to receive(:error).with(
        'VANotify::IcnJob retries exhausted',
        {
          job_id: 123,
          error_class: 'RuntimeError',
          error_message: 'an error occurred!'
        }
      )
      expect(StatsD).to receive(:increment).with('sidekiq.jobs.va_notify/icn_job.retries_exhausted')
      described_class.sidekiq_retries_exhausted_block.call(msg, error)
    end
  end
end
