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
  end
end
