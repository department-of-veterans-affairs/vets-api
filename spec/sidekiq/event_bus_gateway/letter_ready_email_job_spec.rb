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

  let(:bgs_profile) do
    {
      first_nm: 'Joe',
      last_nm: 'Smith',
      brthdy_dt: 30.years.ago,
      ssn_nbr: '123456789'
    }
  end

  let(:mpi_profile) { build(:mpi_profile) }
  let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }
  let(:user_account) { create(:user_account, icn: mpi_profile_response.profile.icn) }

  context 'when an error does not occur' do
    before do
      user_account
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
    end

    it 'sends an email using VA Notify and creates an EventBusGatewayNotification' do
      expected_args = {
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation: { host: Settings.hostname, first_name: 'Joe' }
      }
      expect(va_notify_service).to receive(:send_email).with(expected_args)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to change(EventBusGatewayNotification, :count).by(1)
      ebg_noti = EventBusGatewayNotification.last
      expect(ebg_noti.user_account).to eq(user_account)
      expect(ebg_noti.va_notify_id).to eq(notification_id)
      expect(ebg_noti.template_id).to eq(template_id)
    end
  end

  context 'when a VA Notify error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_raise(StandardError)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:error_message) { 'LetterReadyEmailJob email error' }
    let(:message_detail) { 'StandardError' }
    let(:tags) { ['service:event-bus-gateway', "function: #{error_message}"] }

    it 'does not send an email, logs the error, and increments the statsd metric' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with('event_bus_gateway', tags:)
      expect do
        subject.new.perform(participant_id, template_id)
      end.not_to change(EventBusGatewayNotification, :count)
    end
  end

  context 'when a BGS error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(nil)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:error_message) { 'LetterReadyEmailJob email error' }
    let(:message_detail) { 'Participant ID cannot be found in BGS' }
    let(:tags) { ['service:event-bus-gateway', "function: #{error_message}"] }

    it 'does not send the email, logs the error, and increments the statsd metric' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with('event_bus_gateway', tags:)
      expect do
        subject.new.perform(participant_id, template_id)
      end.not_to change(EventBusGatewayNotification, :count)
    end
  end

  context 'when a MPI error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      expect_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(nil)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:error_message) { 'LetterReadyEmailJob email error' }
    let(:message_detail) { 'Failed to fetch MPI profile' }
    let(:tags) { ['service:event-bus-gateway', "function: #{error_message}"] }

    it 'does not send the email, logs the error, and increments the statsd metric' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with('event_bus_gateway', tags:)
      expect do
        subject.new.perform(participant_id, template_id)
      end.not_to change(EventBusGatewayNotification, :count)
    end
  end
end
