# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'

RSpec.describe EventBusGateway::LetterReadyEmailJob, type: :job do
  subject { described_class }

  let(:participant_id) { '1234' }
  let(:template_id) { '5678' }

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
      expect_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return({ first_nm: 'Joe' })
      expected_args = {
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation: { host: Settings.hostname, first_name: 'Joe' }
      }
      expect(va_notify_service).to receive(:send_email).with(expected_args)
      subject.new.perform(participant_id, template_id)
    end
  end

  context 'when a VA Notify error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_raise(StandardError)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:error_message) { 'LetterReadyEmailJob errored' }
    let(:message_detail) { 'StandardError' }
    let(:tags) { ['service:event-bus-gateway', "function: #{error_message}"] }

    it 'does not send an email, logs the error, and increments the statsd metric' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with('event_bus_gateway', tags:)
      subject.new.perform(participant_id, template_id)
    end
  end

  context 'when a BGS error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(nil)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:error_message) { 'LetterReadyEmailJob errored' }
    let(:message_detail) { 'Participant ID cannot be found in BGS' }
    let(:tags) { ['service:event-bus-gateway', "function: #{error_message}"] }

    it 'does not send the email, logs the error, and increments the statsd metric' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with('event_bus_gateway', tags:)
      subject.new.perform(participant_id, template_id)
    end
  end
end
