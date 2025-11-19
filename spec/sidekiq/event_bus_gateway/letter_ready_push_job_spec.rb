# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'
require_relative '../../../app/sidekiq/event_bus_gateway/constants'
require_relative 'shared_examples_letter_ready_job'

RSpec.describe EventBusGateway::LetterReadyPushJob, type: :job do
  subject { described_class }

  let(:participant_id) { '1234' }
  let(:template_id) { '5678' }
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
      allow(service).to receive(:send_push).and_return(double(id: notification_id))
    end
  end

  let(:expected_push_args) do
    {
      mobile_app: 'VA_FLAGSHIP_APP',
      recipient_identifier: { id_value: mpi_profile_response.profile.icn, id_type: 'ICN' },
      template_id:,
      personalisation: {}
    }
  end

  # Shared setup for most test scenarios
  before do
    allow(VaNotify::Service).to receive(:new)
      .with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key)
      .and_return(va_notify_service)
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
      .and_return(mpi_profile_response)
    allow_any_instance_of(BGS::PersonWebService)
      .to receive(:find_person_by_ptcpnt_id)
      .and_return(bgs_profile)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
  end

  describe 'successful push notification' do
    it 'sends push notification with correct arguments' do
      expect(va_notify_service).to receive(:send_push).with(expected_push_args)
      subject.new.perform(participant_id, template_id)
    end

    it 'creates EventBusGatewayPushNotification record' do
      expect do
        subject.new.perform(participant_id, template_id)
      end.to change(EventBusGatewayPushNotification, :count).by(1)

      notification = EventBusGatewayPushNotification.last
      expect(notification.user_account).to eq(user_account)
      expect(notification.template_id).to eq(template_id)
    end

    it 'increments success metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::STATSD_METRIC_PREFIX}.success",
        tags: EventBusGateway::Constants::DD_TAGS
      )
      subject.new.perform(participant_id, template_id)
    end

    it 'configures VaNotify::Service with correct API key' do
      expect(VaNotify::Service).to receive(:new)
        .with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key)
        .and_return(va_notify_service)
      subject.new.perform(participant_id, template_id)
    end
  end

  describe '#send_push_notification' do
    it 'sends push and creates notification record' do
      job_instance = subject.new

      expect(va_notify_service).to receive(:send_push).with(expected_push_args)
      expect do
        job_instance.send(:send_push_notification, mpi_profile.icn, template_id)
      end.to change(EventBusGatewayPushNotification, :count).by(1)
    end
  end

  describe 'ICN validation' do
    let(:error_message) { 'LetterReadyPushJob push error' }
    let(:message_detail) { 'Failed to fetch ICN' }
    let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }

    shared_examples 'raises ICN error' do
      it 'raises error immediately and does not send notification' do
        expect(va_notify_service).not_to receive(:send_push)
        expect(EventBusGatewayPushNotification).not_to receive(:create!)

        expect(Rails.logger).to receive(:error)
          .with(error_message, { message: message_detail })
        expect(StatsD).to receive(:increment)
          .with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)

        expect do
          subject.new.perform(participant_id, template_id)
        end.to raise_error(EventBusGateway::IcnNotFoundError, message_detail)
      end
    end

    context 'when ICN is nil' do
      let(:mpi_profile) { build(:mpi_profile, icn: nil) }

      include_examples 'raises ICN error'
    end

    context 'when ICN is blank' do
      let(:mpi_profile) { build(:mpi_profile, icn: '') }

      include_examples 'raises ICN error'
    end
  end

  describe 'pre-provided ICN' do
    let!(:user_account_with_provided_icn) { create(:user_account, icn:) }

    let(:expected_push_args_with_icn) do
      {
        mobile_app: 'VA_FLAGSHIP_APP',
        recipient_identifier: { id_value: icn, id_type: 'ICN' },
        template_id:,
        personalisation: {}
      }
    end

    it 'uses provided ICN instead of fetching from MPI' do
      expect_any_instance_of(described_class).not_to receive(:get_mpi_profile)
      subject.new.perform(participant_id, template_id, icn)
    end

    it 'sends push notification with provided ICN' do
      expect(va_notify_service).to receive(:send_push).with(expected_push_args_with_icn)
      subject.new.perform(participant_id, template_id, icn)
    end
  end

  describe 'error handling' do
    context 'when VA Notify service initialization fails' do
      before do
        allow(VaNotify::Service).to receive(:new)
          .with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key)
          .and_raise(StandardError, 'Service initialization failed')
      end

      include_examples 'letter ready job va notify error handling', 'Push', 'push notification'

      it 'does not send push notification' do
        expect(va_notify_service).not_to receive(:send_push)
        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error(StandardError, 'Service initialization failed')
      end
    end

    context 'when VA Notify send_push fails' do
      let(:notify_error) { StandardError.new('Notify service error') }

      before do
        allow(va_notify_service).to receive(:send_push).and_raise(notify_error)
      end

      it 'records notification send failure and re-raises error' do
        expect_any_instance_of(described_class)
          .to receive(:record_notification_send_failure)
          .with(notify_error, 'Push')

        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error(notify_error)
      end
    end

    context 'when BGS service fails' do
      include_examples 'letter ready job bgs error handling', 'Push'

      it 'does not send notification and does not change notification count' do
        expect(va_notify_service).not_to receive(:send_push)

        expect do
          subject.new.perform(participant_id, template_id)
        end.to raise_error(EventBusGateway::BgsPersonNotFoundError, 'Participant ID cannot be found in BGS')
          .and not_change(EventBusGatewayNotification, :count)
      end
    end

    context 'when MPI service fails' do
      include_examples 'letter ready job mpi error handling', 'Push'

      it 'does not send notification and does not change notification count' do
        expect(va_notify_service).not_to receive(:send_push)

        expect do
          subject.new.perform(participant_id, template_id)
        end.to raise_error(EventBusGateway::MpiProfileNotFoundError, 'Failed to fetch MPI profile')
          .and not_change(EventBusGatewayNotification, :count)
      end
    end

    context 'when MPI profile is nil' do
      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(nil)
      end

      it 'raises error for missing MPI profile' do
        expect(va_notify_service).not_to receive(:send_push)

        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error(EventBusGateway::MpiProfileNotFoundError, 'Failed to fetch MPI profile')
      end
    end

    context 'when notification creation fails' do
      let(:creation_error) { ActiveRecord::RecordInvalid.new }

      before do
        allow(EventBusGatewayPushNotification).to receive(:create!).and_raise(creation_error)
      end

      it 'records notification send failure and re-raises error' do
        expect_any_instance_of(described_class)
          .to receive(:record_notification_send_failure)
          .with(creation_error, 'Push')

        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error(creation_error)
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
        'LetterReadyPushJob retries exhausted',
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
        'event_bus_gateway.letter_ready_push.exhausted',
        tags: expected_tags
      )

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end
  end

  include_examples 'letter ready job sidekiq retries exhausted', 'Push'
end
