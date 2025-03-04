# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob, type: :job do
  let(:email) { 'test@example.com' }
  let(:template_id) { 'template-id' }
  let(:poa_request) { create(:power_of_attorney_request) }
  let(:type) { 'requested' }
  let(:api_key) { 'test-api-key' }
  let(:response) { { 'id' => Faker::Internet.uuid } }
  let(:client) { instance_double(VaNotify::Service) }

  before do
    allow(VaNotify::Service).to receive(:new).with(api_key, {}).and_return(client)
    allow(client).to receive(:send_email).and_return(response)
  end

  describe '#perform' do
    it 'sends an email using the template id and creates a notification record' do
      expect(client).to receive(:send_email).with(
        { email_address: email,
          template_id: }
      ).and_return(response)

      expect do
        described_class.new.perform(email, template_id, poa_request.id, type, api_key)
      end.to change(AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification, :count).by(1)

      notification = AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification.last
      expect(notification.type).to eq(type)
      expect(notification.power_of_attorney_request).to eq(poa_request)
      expect(notification.notification_id).to eq(response['id'])
    end

    it 'handles VANotify::Error with status code 400' do
      error = VANotify::Error.new(400, 'Bad Request')
      allow(client).to receive(:send_email).and_raise(error)

      expect_any_instance_of(described_class).to receive(:log_exception_to_sentry).with(
        error,
        { args: { template_id: } },
        { error: :accredited_representative_portal_power_of_attorney_request_email_job }
      )

      expect do
        described_class.new.perform(email, template_id, poa_request.id, type, api_key)
      end.not_to(change(AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification, :count))
    end

    it 'raises VANotify::Error with other status codes' do
      error = VANotify::Error.new(500, 'Internal Server Error')
      allow(client).to receive(:send_email).and_raise(error)

      expect do
        described_class.new.perform(email, template_id, poa_request.id, type, api_key)
      end.to raise_error(VANotify::Error)
    end
  end
end
