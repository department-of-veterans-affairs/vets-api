# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'
require_relative '../../../app/sidekiq/event_bus_gateway/constants'
require_relative 'shared_examples_letter_ready_job'

RSpec.describe EventBusGateway::LetterReadyEmailJob, type: :job do
  subject { described_class }

  let(:participant_id) { '1234' }
  let(:template_id) { '5678' }
  let(:first_name) { 'Joe' }
  let(:icn) { '1234567890V123456' }

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
        personalisation: { host: Settings.hostname, first_name: first_name }
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
    end

    include_examples 'letter ready job va notify error handling', 'Email', 'email'

    it 'does not send an email and does not change EventBusGatewayNotification count' do
      expect(va_notify_service).not_to receive(:send_email)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(StandardError).and not_change(EventBusGatewayNotification, :count)
    end
  end

  context 'when a BGS error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
    end

    include_examples 'letter ready job bgs error handling', 'Email'

    it 'does not send the email and does not change EventBusGatewayNotification count' do
      expect(va_notify_service).not_to receive(:send_email)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(StandardError,
                         'Participant ID cannot be found in BGS').and not_change(EventBusGatewayNotification, :count)
    end
  end

  context 'when a MPI error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
    end

    include_examples 'letter ready job mpi error handling', 'Email'

    it 'does not send the email and does not change EventBusGatewayNotification count' do
      expect(va_notify_service).not_to receive(:send_email)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(RuntimeError,
                         'Failed to fetch MPI profile').and not_change(EventBusGatewayNotification, :count)
    end
  end

  context 'with pre-provided data' do
    before do
      user_account
      allow(VaNotify::Service).to receive(:new).with(
        EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
        { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
      ).and_return(va_notify_service)
      allow(StatsD).to receive(:increment)
    end

    it 'uses provided data instead of fetching' do
      expect_any_instance_of(described_class).not_to receive(:get_bgs_person)
      expect_any_instance_of(described_class).not_to receive(:get_mpi_profile)

      subject.new.perform(participant_id, template_id, first_name, icn)
    end

    it 'sends email with provided data' do
      expect(va_notify_service).to receive(:send_email).with(
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id: template_id,
        personalisation: { 
          host: EventBusGateway::Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
          first_name: first_name
        }
      ).and_return(double(id: notification_id))

      subject.new.perform(participant_id, template_id, first_name, icn)
    end
  end

  describe 'sidekiq_retries_exhausted callback' do
    let(:msg) do
      {
        'jid' => '12345',
        'error_class' => 'StandardError',
        'error_message' => 'Test error'
      }
    end
    let(:exception) { StandardError.new('Test error') }

    before do
      allow(Time).to receive(:now).and_return(Time.zone.parse('2023-01-01 12:00:00 UTC'))
    end

    it 'logs error details' do
      expect(Rails.logger).to receive(:error).with(
        'LetterReadyEmailJob retries exhausted',
        {
          job_id: '12345',
          timestamp: Time.zone.parse('2023-01-01 12:00:00 UTC'),
          error_class: 'StandardError',
          error_message: 'Test error'
        }
      )

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end

    it 'increments exhausted metric with correct tags' do
      expected_tags = EventBusGateway::Constants::DD_TAGS + ['function: Test error']
      expect(StatsD).to receive(:increment).with(
        'event_bus_gateway.letter_ready_email.exhausted',
        tags: expected_tags
      )

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end
  end

  describe 'metrics tracking' do
    before do
      user_account
      allow(VaNotify::Service).to receive(:new).with(
        EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
        { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
      ).and_return(va_notify_service)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(StatsD).to receive(:increment)
    end

    it 'increments success metric on successful email send' do
      expect(StatsD).to receive(:increment).with(
        'event_bus_gateway.letter_ready_email.success',
        tags: EventBusGateway::Constants::DD_TAGS
      )

      subject.new.perform(participant_id, template_id)
    end
  end

  describe 'notification creation' do
    before do
      user_account
      allow(VaNotify::Service).to receive(:new).with(
        EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
        { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
      ).and_return(va_notify_service)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(StatsD).to receive(:increment)
    end

    it 'creates EventBusGatewayNotification with correct attributes' do
      expect(EventBusGatewayNotification).to receive(:create).with(
        user_account: user_account,
        template_id: template_id,
        va_notify_id: notification_id
      )

      subject.new.perform(participant_id, template_id)
    end
  end

  describe 'notify client configuration' do
    before do
      user_account
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(StatsD).to receive(:increment)
    end

    it 'configures VaNotify::Service with correct parameters' do
      expect(VaNotify::Service).to receive(:new).with(
        EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
        { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
      ).and_return(va_notify_service)

      subject.new.perform(participant_id, template_id)
    end
  end

  describe 'edge cases' do
    context 'when first_name is nil' do
      let(:bgs_profile_nil_name) do
        {
          first_nm: nil,
          last_nm: 'Smith',
          brthdy_dt: 30.years.ago,
          ssn_nbr: '123456789'
        }
      end

      before do
        user_account
        allow(VaNotify::Service).to receive(:new).with(
          EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
          { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
        ).and_return(va_notify_service)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile_nil_name)
        allow(StatsD).to receive(:increment)
      end

      it 'handles nil first_name gracefully' do
        expect(va_notify_service).to receive(:send_email).with(
          recipient_identifier: { id_value: participant_id, id_type: 'PID' },
          template_id: template_id,
          personalisation: { 
            host: EventBusGateway::Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
            first_name: nil
          }
        ).and_return(double(id: notification_id))

        subject.new.perform(participant_id, template_id, nil, icn)
      end
    end

    context 'when hostname mapping exists' do
      before do
        user_account
        allow(Settings).to receive(:hostname).and_return('test-hostname')
        stub_const('EventBusGateway::Constants::HOSTNAME_MAPPING', { 'test-hostname' => 'mapped-hostname' })
        allow(VaNotify::Service).to receive(:new).with(
          EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
          { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
        ).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(StatsD).to receive(:increment)
      end

      it 'uses mapped hostname in personalisation' do
        expect(va_notify_service).to receive(:send_email).with(
          recipient_identifier: { id_value: participant_id, id_type: 'PID' },
          template_id: template_id,
          personalisation: { 
            host: 'mapped-hostname',
            first_name: 'Joe'
          }
        ).and_return(double(id: notification_id))

        subject.new.perform(participant_id, template_id)
      end
    end

    context 'when hostname mapping does not exist' do
      before do
        user_account
        allow(Settings).to receive(:hostname).and_return('unmapped-hostname')
        stub_const('EventBusGateway::Constants::HOSTNAME_MAPPING', {})
        allow(VaNotify::Service).to receive(:new).with(
          EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
          { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
        ).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(StatsD).to receive(:increment)
      end

      it 'uses original hostname in personalisation' do
        expect(va_notify_service).to receive(:send_email).with(
          recipient_identifier: { id_value: participant_id, id_type: 'PID' },
          template_id: template_id,
          personalisation: { 
            host: 'unmapped-hostname',
            first_name: 'Joe'
          }
        ).and_return(double(id: notification_id))

        subject.new.perform(participant_id, template_id)
      end
    end
  end

  describe 'error handling' do
    context 'when notify client raises an error' do
      let(:notify_error) { StandardError.new('Notify service error') }

      before do
        user_account
        allow(VaNotify::Service).to receive(:new).with(
          EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
          { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
        ).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(va_notify_service).to receive(:send_email).and_raise(notify_error)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'records notification send failure' do
        expect_any_instance_of(described_class).to receive(:record_notification_send_failure).with(notify_error, 'Email')

        expect { subject.new.perform(participant_id, template_id) }.to raise_error(notify_error)
      end

      it 're-raises the error' do
        allow_any_instance_of(described_class).to receive(:record_notification_send_failure)

        expect { subject.new.perform(participant_id, template_id) }.to raise_error(notify_error)
      end
    end

    context 'when notification creation fails' do
      let(:creation_error) { ActiveRecord::RecordInvalid.new }

      before do
        user_account
        allow(VaNotify::Service).to receive(:new).with(
          EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
          { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
        ).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(EventBusGatewayNotification).to receive(:create).and_raise(creation_error)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'records notification send failure' do
        expect_any_instance_of(described_class).to receive(:record_notification_send_failure).with(creation_error, 'Email')

        expect { subject.new.perform(participant_id, template_id) }.to raise_error(creation_error)
      end
    end
  end
end
