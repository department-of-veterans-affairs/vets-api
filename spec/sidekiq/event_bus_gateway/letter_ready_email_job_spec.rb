# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'
require_relative '../../../app/sidekiq/event_bus_gateway/constants'

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
      allow(StatsD).to receive(:increment)
    end

    it 'sends an email using VA Notify and creates an EventBusGatewayNotification' do
      expected_args = {
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation: { host: Settings.hostname, first_name: 'Joe' }
      }
      expect(va_notify_service).to receive(:send_email).with(expected_args)
      expect(StatsD).to receive(:increment)
        .with("#{described_class::STATSD_METRIC_PREFIX}.success", tags: EventBusGateway::Constants::DD_TAGS)
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
    let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }

    it 'does not send an email, logs the error, increments the statsd metric, and re-raises for retry' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(StandardError).and not_change(EventBusGatewayNotification, :count)
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
    let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }

    it 'does not send the email, logs the error, increments the statsd metric, and re-raises for retry' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(StandardError, message_detail).and not_change(EventBusGatewayNotification, :count)
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
    let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }

    it 'does not send the email, logs the error, increments the statsd metric, and re-raises for retry' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(RuntimeError, message_detail).and not_change(EventBusGatewayNotification, :count)
    end
  end

  context 'when sidekiq retries are exhausted' do
    before do
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:job_id) { 'test-job-id-123' }
    let(:error_class) { 'StandardError' }
    let(:error_message) { 'Some error message' }
    let(:msg) do
      {
        'jid' => job_id,
        'error_class' => error_class,
        'error_message' => error_message
      }
    end
    let(:exception) { StandardError.new(error_message) }

    it 'logs the exhausted retries and increments the statsd metric' do
      # Get the retries exhausted callback from the job class
      retries_exhausted_callback = described_class.sidekiq_retries_exhausted_block

      expect(Rails.logger).to receive(:error)
        .with('LetterReadyEmailJob retries exhausted', {
                job_id:,
                timestamp: be_within(1.second).of(Time.now.utc),
                error_class:,
                error_message:
              })

      expect(StatsD).to receive(:increment)
                    .with("#{described_class::STATSD_METRIC_PREFIX}.exhausted",
                          tags: EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"])

      retries_exhausted_callback.call(msg, exception)
    end
  end
end
