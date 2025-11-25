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
  let!(:user_account) { create(:user_account, icn: mpi_profile_response.profile.icn) }

  let(:va_notify_service) do
    instance_double(VaNotify::Service).tap do |service|
      response = instance_double(Notifications::Client::ResponseNotification, id: notification_id)
      allow(service).to receive(:send_email).and_return(response)
    end
  end

  let(:expected_email_args) do
    {
      recipient_identifier: { id_value: participant_id, id_type: 'PID' },
      template_id:,
      personalisation: {
        host: EventBusGateway::Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
        first_name:
      }
    }
  end

  let(:notify_service_params) do
    {
      api_key: EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
      options: { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
    }
  end

  # Shared setup for most test scenarios
  before do
    allow(VaNotify::Service).to receive(:new).with(
      EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
      { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
    ).and_return(va_notify_service)
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
      .and_return(mpi_profile_response)
    allow_any_instance_of(BGS::PersonWebService)
      .to receive(:find_person_by_ptcpnt_id)
      .and_return(bgs_profile)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
  end

  describe 'successful email notification' do
    it 'sends email with correct arguments' do
      expect(va_notify_service).to receive(:send_email).with(expected_email_args)
      subject.new.perform(participant_id, template_id)
    end

    it 'creates EventBusGatewayNotification record with correct attributes' do
      expect do
        subject.new.perform(participant_id, template_id)
      end.to change(EventBusGatewayNotification, :count).by(1)

      notification = EventBusGatewayNotification.last
      expect(notification.user_account).to eq(user_account)
      expect(notification.va_notify_id).to eq(notification_id)
      expect(notification.template_id).to eq(template_id)
    end

    it 'increments success metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::STATSD_METRIC_PREFIX}.success",
        tags: EventBusGateway::Constants::DD_TAGS
      )
      subject.new.perform(participant_id, template_id)
    end

    it 'configures VaNotify::Service with correct parameters' do
      expect(VaNotify::Service).to receive(:new).with(
        EventBusGateway::Constants::NOTIFY_SETTINGS.api_key,
        { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' }
      ).and_return(va_notify_service)

      subject.new.perform(participant_id, template_id)
    end
  end

  describe '#send_email_notification' do
    it 'sends email and creates notification record' do
      job_instance = subject.new

      expect(va_notify_service).to receive(:send_email).with(expected_email_args)
      expect do
        job_instance.send(:send_email_notification, participant_id, template_id, first_name, mpi_profile.icn)
      end.to change(EventBusGatewayNotification, :count).by(1)
    end

    context 'when notification record fails to save' do
      let(:invalid_notification) do
        instance_double(EventBusGatewayNotification, persisted?: false,
                                                     errors: double(full_messages: ['Validation failed']))
      end

      before do
        allow(EventBusGatewayNotification).to receive(:create).and_return(invalid_notification)
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs a warning with error details' do
        job_instance = subject.new

        expect(Rails.logger).to receive(:warn).with(
          'LetterReadyEmailJob notification record failed to save',
          {
            errors: ['Validation failed'],
            template_id:,
            va_notify_id: notification_id
          }
        )

        job_instance.send(:send_email_notification, participant_id, template_id, first_name, mpi_profile.icn)
      end

      it 'still sends the email successfully' do
        job_instance = subject.new

        expect(va_notify_service).to receive(:send_email).with(expected_email_args)

        job_instance.send(:send_email_notification, participant_id, template_id, first_name, mpi_profile.icn)
      end

      it 'does not raise an error' do
        job_instance = subject.new

        expect do
          job_instance.send(:send_email_notification, participant_id, template_id, first_name, mpi_profile.icn)
        end.not_to raise_error
      end
    end
  end

  describe '#hostname_for_template' do
    let(:job_instance) { subject.new }

    context 'when hostname mapping exists' do
      before do
        allow(Settings).to receive(:hostname).and_return('test-hostname')
        stub_const('EventBusGateway::Constants::HOSTNAME_MAPPING', { 'test-hostname' => 'mapped-hostname' })
      end

      it 'returns the mapped hostname' do
        result = job_instance.send(:hostname_for_template)
        expect(result).to eq('mapped-hostname')
      end
    end

    context 'when hostname mapping does not exist' do
      before do
        allow(Settings).to receive(:hostname).and_return('unmapped-hostname')
        stub_const('EventBusGateway::Constants::HOSTNAME_MAPPING', {})
      end

      it 'returns the original hostname' do
        result = job_instance.send(:hostname_for_template)
        expect(result).to eq('unmapped-hostname')
      end
    end
  end

  describe 'pre-provided data' do
    it 'uses provided data instead of fetching from BGS and MPI' do
      expect_any_instance_of(described_class).not_to receive(:get_bgs_person)
      expect_any_instance_of(described_class).not_to receive(:get_mpi_profile)

      subject.new.perform(participant_id, template_id, first_name, icn)
    end

    it 'sends email with provided first_name' do
      expect(va_notify_service).to receive(:send_email).with(expected_email_args)
      subject.new.perform(participant_id, template_id, first_name, icn)
    end
  end

  describe 'when ICN is not present' do
    let(:mpi_profile) { build(:mpi_profile, icn: nil) }

    it 'returns early without sending email' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(StatsD).not_to receive(:increment).with(
        "#{described_class::STATSD_METRIC_PREFIX}.success",
        tags: EventBusGateway::Constants::DD_TAGS
      )

      result = subject.new.perform(participant_id, template_id)
      expect(result).to be_nil
    end

    it 'does not create notification record' do
      expect do
        subject.new.perform(participant_id, template_id)
      end.not_to change(EventBusGatewayNotification, :count)
    end

    it 'logs the skipped notification' do
      expect(Rails.logger).to receive(:error).with(
        'LetterReadyEmailJob email skipped',
        {
          notification_type: 'email',
          reason: 'ICN not available',
          template_id:
        }
      )

      subject.new.perform(participant_id, template_id)
    end

    it 'increments the skipped metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::STATSD_METRIC_PREFIX}.skipped",
        tags: EventBusGateway::Constants::DD_TAGS + ['notification_type:email', 'reason:icn_not_available']
      )

      subject.new.perform(participant_id, template_id)
    end
  end

  describe 'when first_name is not present' do
    let(:bgs_profile) do
      {
        first_nm: nil,
        last_nm: 'Smith',
        brthdy_dt: 30.years.ago,
        ssn_nbr: '123456789'
      }
    end

    it 'returns early without sending email' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(StatsD).not_to receive(:increment).with(
        "#{described_class::STATSD_METRIC_PREFIX}.success",
        tags: EventBusGateway::Constants::DD_TAGS
      )

      result = subject.new.perform(participant_id, template_id)
      expect(result).to be_nil
    end

    it 'does not create notification record' do
      expect do
        subject.new.perform(participant_id, template_id)
      end.not_to change(EventBusGatewayNotification, :count)
    end

    it 'logs the skipped notification' do
      expect(Rails.logger).to receive(:error).with(
        'LetterReadyEmailJob email skipped',
        {
          notification_type: 'email',
          reason: 'First Name not available',
          template_id:
        }
      )

      subject.new.perform(participant_id, template_id)
    end

    it 'increments the skipped metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::STATSD_METRIC_PREFIX}.skipped",
        tags: EventBusGateway::Constants::DD_TAGS + ['notification_type:email', 'reason:first_name_not_available']
      )

      subject.new.perform(participant_id, template_id)
    end

    context 'when first_name is empty string' do
      it 'also returns early without sending email' do
        expect(va_notify_service).not_to receive(:send_email)

        result = subject.new.perform(participant_id, template_id, '', icn)
        expect(result).to be_nil
      end

      it 'logs the skipped notification' do
        expect(Rails.logger).to receive(:error).with(
          'LetterReadyEmailJob email skipped',
          {
            notification_type: 'email',
            reason: 'First Name not available',
            template_id:
          }
        )

        subject.new.perform(participant_id, template_id, '', icn)
      end
    end
  end

  describe 'error handling' do
    context 'when VA Notify service initialization fails' do
      before do
        allow(VaNotify::Service).to receive(:new).and_raise(StandardError, 'Service initialization failed')
      end

      include_examples 'letter ready job va notify error handling', 'Email'

      it 'does not send email and does not change notification count' do
        expect(va_notify_service).not_to receive(:send_email)

        expect do
          subject.new.perform(participant_id, template_id)
        end.to raise_error(StandardError, 'Service initialization failed')
          .and not_change(EventBusGatewayNotification, :count)
      end
    end

    context 'when VA Notify send_email fails' do
      let(:notify_error) { StandardError.new('Notify service error') }

      before do
        allow(va_notify_service).to receive(:send_email).and_raise(notify_error)
      end

      it 'records notification send failure and re-raises error' do
        expect_any_instance_of(described_class)
          .to receive(:record_notification_send_failure)
          .with(notify_error, 'Email')

        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error(notify_error)
      end
    end

    context 'when BGS service fails' do
      include_examples 'letter ready job bgs error handling', 'Email'

      it 'does not send email and does not change notification count' do
        expect(va_notify_service).not_to receive(:send_email)

        expect do
          subject.new.perform(participant_id, template_id)
        end.to raise_error(EventBusGateway::Errors::BgsPersonNotFoundError, 'Participant ID cannot be found in BGS')
          .and not_change(EventBusGatewayNotification, :count)
      end
    end

    context 'when MPI service fails' do
      include_examples 'letter ready job mpi error handling', 'Email'

      it 'does not send email and does not change notification count' do
        expect(va_notify_service).not_to receive(:send_email)

        expect do
          subject.new.perform(participant_id, template_id)
        end.to raise_error(EventBusGateway::Errors::MpiProfileNotFoundError, 'Failed to fetch MPI profile')
          .and not_change(EventBusGatewayNotification, :count)
      end
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
    let(:frozen_time) { Time.zone.parse('2023-01-01 12:00:00 UTC') }

    before do
      allow(Time).to receive(:now).and_return(frozen_time)
    end

    it 'logs error details with timestamp' do
      expect(Rails.logger).to receive(:error).with(
        'LetterReadyEmailJob retries exhausted',
        {
          job_id: '12345',
          timestamp: frozen_time,
          error_class: 'StandardError',
          error_message: 'Test error'
        }
      )

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end

    it 'increments exhausted metric with error message tag' do
      expected_tags = EventBusGateway::Constants::DD_TAGS + ['function: Test error']

      expect(StatsD).to receive(:increment).with(
        'event_bus_gateway.letter_ready_email.exhausted',
        tags: expected_tags
      )

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end
  end
end
