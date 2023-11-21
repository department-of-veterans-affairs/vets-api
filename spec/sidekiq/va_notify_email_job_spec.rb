# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotifyEmailJob, type: :model do
  let(:email) { 'user@example.com' }
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
        email_address: email,
        template_id:
      )

      described_class.new.perform(email, template_id)
    end

    context 'when vanotify returns a 400 error' do
      it 'rescues and logs the error' do
        VCR.use_cassette('va_notify/bad_request') do
          job = described_class.new
          expect(job).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Exceptions::BackendServiceException),
            {
              args: {
                template_id:,
                personalisation: nil
              }
            },
            {
              error: :va_notify_email_job
            }
          )

          job.perform(email, template_id)
        end
      end
    end
  end
end
