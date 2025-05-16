# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'

RSpec.describe EventBusGateway::LetterReadyEmailJob, type: :job do
  subject { described_class }

  let(:participant_id) { '1234' }
  let(:template_id) { '5678' }
  let(:personalisation) { {} }

  let(:notification_id) { SecureRandom.uuid }
  let(:va_notify_service) do
    service = instance_double(VaNotify::Service)

    response = instance_double(Notifications::Client::ResponseNotification, id: notification_id)
    allow(service).to receive(:send_email).and_return(response)

    service
  end

  context 'when an error does not occur' do
    it 'sends an email using VA Notify' do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      expect(va_notify_service).to receive(:send_email)
      subject.new.perform(participant_id:, template_id:, personalisation:)
    end
  end

  context 'when an error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_raise(StandardError)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:error_message) { 'LetterReadyEmailJob VANotify errored' }
    let(:tags) { ['service:event-bus-gateway', "function: #{error_message}"] }

    it 'does not send an email, logs the error, and increments the statsd metric' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: 'StandardError' })
      expect(StatsD).to receive(:increment).with('event_bus_gateway', tags:)
      subject.new.perform(participant_id:, template_id:, personalisation:)
    end
  end
end
