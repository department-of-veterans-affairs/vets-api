# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob, type: :job do
  let(:power_of_attorney_request_notification) do
    create(:power_of_attorney_request_notification, :with_resolution, type:)
  end
  let(:email) { 'test@example.com' }
  let(:template_id) { 'template-id' }
  let(:type) { 'declined' }
  let(:personalisation) do
    AccreditedRepresentativePortal::EmailPersonalisations::Declined.generate(power_of_attorney_request_notification)
  end
  let(:api_key) { 'test-api-key' }
  let(:response) { Struct.new(:id).new(Faker::Internet.uuid) }
  let(:client) { instance_double(VaNotify::Service) }
  let(:callback_options) do
    {
      callback_klass: 'AccreditedRepresentativePortal::EmailDeliveryStatusCallback',
      callback_metadata: {
        statsd_tags: {
          service: 'accredited-representative-portal',
          function: "poa_request_#{type}_email"
        }
      }
    }
  end

  before do
    allow(VaNotify::Service).to receive(:new).with(api_key, callback_options).and_return(client)
    allow(client).to receive(:send_email).and_return(response)
  end

  describe '#perform' do
    it 'sends an email using the template id and updates the poa_request_notification record' do
      expect(client).to receive(:send_email).with(
        { email_address: power_of_attorney_request_notification.email_address,
          template_id: power_of_attorney_request_notification.template_id,
          personalisation: }
      ).and_return(response)

      expect(power_of_attorney_request_notification.notification_id).to be_nil

      described_class.new.perform(power_of_attorney_request_notification.id, nil, api_key)

      power_of_attorney_request_notification.reload
      expect(power_of_attorney_request_notification.notification_id).to eq(response.id)
    end

    context 'when handling the accredited_representative_portal_email_delivery_callback feature flag' do
      let(:type) { 'requested' }

      context 'when the feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:accredited_representative_portal_email_delivery_callback)
            .and_return(true)
        end

        it 'passes callback options with the correct function tag to VaNotify::Service' do
          expect(VaNotify::Service).to receive(:new).with(api_key, callback_options).and_return(client)
          described_class.new.perform(power_of_attorney_request_notification.id, personalisation, api_key)
        end
      end

      context 'when the feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:accredited_representative_portal_email_delivery_callback)
            .and_return(false)
        end

        it 'does not pass callback options to VaNotify::Service' do
          expect(VaNotify::Service).to receive(:new).with(api_key, nil).and_return(client)
          described_class.new.perform(power_of_attorney_request_notification.id, personalisation, api_key)
        end
      end
    end

    it 'handles VANotify::Error with status code 400 and does not update the poa_request_notification record' do
      error = VANotify::Error.new(400, 'Bad Request')
      allow(client).to receive(:send_email).and_raise(error)

      expect_any_instance_of(described_class).to receive(:log_exception_to_sentry).with(
        error,
        { args: { template_id: power_of_attorney_request_notification.template_id } },
        { error: :accredited_representative_portal_power_of_attorney_request_email_job }
      )

      described_class.new.perform(power_of_attorney_request_notification.id, nil, api_key)
      expect(power_of_attorney_request_notification.notification_id).to be_nil
    end

    it 'raises VANotify::Error with other status codes' do
      error = VANotify::Error.new(500, 'Internal Server Error')
      allow(client).to receive(:send_email).and_raise(error)

      expect do
        described_class.new.perform(power_of_attorney_request_notification.id, nil, api_key)
      end.to raise_error(VANotify::Error)
    end

    context 'when personalisation is explicitly provided' do
      let(:type) { 'declined' }
      let(:explicit_personalisation) { { 'foo' => 'bar' } }

      it 'uses the generated personalisation when the generator returns a value (current precedence)' do
        allow(AccreditedRepresentativePortal::EmailPersonalisations::Declined)
          .to receive(:generate).and_return({ 'generated' => 'value' })

        expect(client).to receive(:send_email).with(
          hash_including(personalisation: { 'generated' => 'value' })
        ).and_return(response)

        described_class.new.perform(power_of_attorney_request_notification.id, explicit_personalisation, api_key)
      end

      it 'falls back to the explicitly provided personalisation when the generator returns nil' do
        allow(AccreditedRepresentativePortal::EmailPersonalisations::Declined)
          .to receive(:generate).and_return(nil)

        expect(client).to receive(:send_email).with(
          hash_including(personalisation: explicit_personalisation)
        ).and_return(response)

        described_class.new.perform(power_of_attorney_request_notification.id, explicit_personalisation, api_key)
      end
    end

    context 'when notification type is unknown' do
      let(:type) { 'declined' }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_email_delivery_callback)
          .and_return(false)

        allow(VaNotify::Service).to receive(:new).with(api_key, nil).and_return(client)
      end

      it 'does not include personalisation and still sends the email' do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_email_delivery_callback)
          .and_return(false)
        allow(VaNotify::Service).to receive(:new).with(api_key, nil).and_return(client)
        allow_any_instance_of(described_class).to receive(:generate_personalisation).and_return(nil)

        expect(client).to receive(:send_email).with(
          satisfy do |h|
            h.is_a?(Hash) &&
              h[:email_address] == power_of_attorney_request_notification.email_address &&
              h[:template_id] == power_of_attorney_request_notification.template_id &&
              !h.key?(:personalisation)
          end
        ).and_return(response)

        described_class.new.perform(power_of_attorney_request_notification.id, nil, api_key)
      end
    end

    describe 'callback function tag per type' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_email_delivery_callback)
          .and_return(true)
      end

      {
        'requested' => 'poa_request_requested_email',
        'declined' => 'poa_request_declined_email',
        'expiring' => 'poa_request_expiring_email',
        'expired' => 'poa_request_expired_email'
      }.each do |notif_type, function_tag|
        context notif_type do
          let(:type) { notif_type }

          it 'passes VaNotify::Service the expected callback options' do
            expected_callback_options = {
              callback_klass: 'AccreditedRepresentativePortal::EmailDeliveryStatusCallback',
              callback_metadata: {
                statsd_tags: {
                  service: 'accredited-representative-portal',
                  function: function_tag
                }
              }
            }
            expect(VaNotify::Service).to receive(:new).with(api_key, expected_callback_options).and_return(client)
            described_class.new.perform(power_of_attorney_request_notification.id, nil, api_key)
          end
        end
      end
    end
  end

  describe 'sidekiq_retries_exhausted hook' do
    it 'logs and increments StatsD' do
      msg = {
        'jid' => 'abc123',
        'class' => 'AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob',
        'error_class' => 'VANotify::Error',
        'error_message' => 'boom'
      }

      expect(Rails.logger).to receive(:error).with(
        'AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob retries exhausted',
        hash_including(job_id: 'abc123', error_class: 'VANotify::Error', error_message: 'boom')
      )

      expect(StatsD).to receive(:increment)
        .with('sidekiq.jobs.accredited_representative_portal/power_of_attorney_request_email_job.retries_exhausted')

      block = if described_class.respond_to?(:sidekiq_retries_exhausted_block)
                described_class.sidekiq_retries_exhausted_block
              else
                described_class.send(:_sidekiq_retries_exhausted_block)
              end
      block.call(msg, StandardError.new('boom'))
    end
  end
end
