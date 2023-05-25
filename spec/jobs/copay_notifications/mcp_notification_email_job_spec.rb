# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CopayNotifications::McpNotificationEmailJob, skip_vet360: true, type: :worker do
  let(:template_id) { 'template_id' }
  let(:email) { 'person43@example.com' }
  let(:backup_email) { 'meepmorp@example.com' }
  let(:vet_id) { '1' }

  before do
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')

    allow(Settings.vanotify.services.va_gov).to receive(:api_key).and_return(
      'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    )
  end

  describe '#perform' do
    it 'sends an email using the template id' do
      VCR.use_cassette('va_profile/contact_information/person_full', VCR::MATCH_EVERYTHING) do
        client = double
        expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.va_gov.api_key).and_return(client)

        expect(client).to receive(:send_email).with(
          email_address: email,
          template_id:
        )

        CopayNotifications::McpNotificationEmailJob.new.perform(vet_id, template_id)
      end
    end

    context 'when no email address resovles' do
      let(:vet_id) { '6767671' }

      it 'uses backup email' do
        VCR.use_cassette('va_profile/contact_information/person_error', VCR::MATCH_EVERYTHING) do
          job = described_class.new
          client = double
          expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.va_gov.api_key).and_return(client)

          expect(client).to receive(:send_email).with(
            email_address: backup_email,
            template_id:
          )
          job.perform(vet_id, template_id, backup_email)
        end
      end

      it 'logs an error' do
        VCR.use_cassette('va_profile/contact_information/person_error', VCR::MATCH_EVERYTHING) do
          job = described_class.new
          expect(job).to receive(:log_exception_to_sentry).with(
            instance_of(CopayNotifications::ProfileMissingEmail), {}, { error: :mcp_notification_email_job }
          )
          job.perform(vet_id, template_id)
        end
      end
    end

    context 'when vanotify returns a 400 error' do
      it 'rescues and logs the error' do
        VCR.use_cassette('va_profile/contact_information/person_full', VCR::MATCH_EVERYTHING) do
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

            job.perform(vet_id, template_id)
          end
        end
      end
    end
  end
end
