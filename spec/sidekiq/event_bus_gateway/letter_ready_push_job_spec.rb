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
  let(:va_notify_service) do
    service = instance_double(VaNotify::Service)

    response = double(id: notification_id)
    allow(service).to receive(:send_push).and_return(response)

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
      allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(StatsD).to receive(:increment)
    end

    it 'sends a push notification using VA Notify and creates an EventBusGatewayPushNotification' do
      expected_args = {
        mobile_app: 'VA_FLAGSHIP_APP',
        recipient_identifier: { id_value: mpi_profile_response.profile.icn, id_type: 'ICN' },
        template_id:,
        personalisation: {}
      }
      expect(va_notify_service).to receive(:send_push).with(expected_args)
      expect(StatsD).to receive(:increment)
        .with("#{described_class::STATSD_METRIC_PREFIX}.success", tags: EventBusGateway::Constants::DD_TAGS)
      expect(EventBusGatewayPushNotification).to receive(:create!).with(
        user_account: user_account,
        template_id: template_id
      )
      
      subject.new.perform(participant_id, template_id)
    end
  end

  context 'when ICN cannot be found' do
    let(:mpi_profile_no_icn) { build(:mpi_profile, icn: nil) }
    let(:error_message) { 'LetterReadyPushJob push error' }
    let(:message_detail) { 'Failed to fetch ICN' }
    let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }
    let(:mpi_profile_response_no_icn) { create(:find_profile_response, profile: mpi_profile_no_icn) }

    before do
      allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response_no_icn)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    it 'does not send the push notification, logs the error, increments the statsd metric, and re-raises for retry' do
      expect(va_notify_service).not_to receive(:send_push)
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(StandardError, message_detail)
    end
  end

  context 'when a VA Notify error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_raise(StandardError)
    end

    include_examples 'letter ready job va notify error handling', 'Push', 'push notification'

    it 'does not send a push notification' do
      expect(va_notify_service).not_to receive(:send_push)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(StandardError)
    end
  end

  context 'when a BGS error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
    end

    include_examples 'letter ready job bgs error handling', 'Push'

    it 'does not send the push notification and does not change EventBusGatewayNotification count' do
      expect(va_notify_service).not_to receive(:send_push)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(StandardError,
                         'Participant ID cannot be found in BGS').and not_change(EventBusGatewayNotification, :count)
    end
  end

  context 'when a MPI error occurs' do
    before do
      allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
    end

    include_examples 'letter ready job mpi error handling', 'Push'

    it 'does not send the push notification and does not change EventBusGatewayNotification count' do
      expect(va_notify_service).not_to receive(:send_push)
      expect do
        subject.new.perform(participant_id, template_id)
      end.to raise_error(RuntimeError,
                         'Failed to fetch MPI profile').and not_change(EventBusGatewayNotification, :count)
    end
  end

  include_examples 'letter ready job sidekiq retries exhausted', 'Push'

  context 'with pre-provided ICN' do
    before do
      user_account
      allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
      allow(EventBusGatewayPushNotification).to receive(:create!)
      allow(StatsD).to receive(:increment)
    end

    it 'uses provided ICN instead of fetching' do
      expect_any_instance_of(described_class).not_to receive(:get_mpi_profile)

      subject.new.perform(participant_id, template_id, icn)
    end

    it 'sends push notification with provided ICN' do
      expect(va_notify_service).to receive(:send_push).with(
        mobile_app: 'VA_FLAGSHIP_APP',
        recipient_identifier: { id_value: icn, id_type: 'ICN' },
        template_id: template_id,
        personalisation: {}
      )

      subject.new.perform(participant_id, template_id, icn)
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
        'LetterReadyPushJob retries exhausted',
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
        'event_bus_gateway.letter_ready_push.exhausted',
        tags: expected_tags
      )

      described_class.sidekiq_retries_exhausted_block.call(msg, exception)
    end
  end

  describe 'metrics tracking' do
    before do
      user_account
      allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(StatsD).to receive(:increment)
    end

    it 'increments success metric on successful push send' do
      expect(StatsD).to receive(:increment).with(
        'event_bus_gateway.letter_ready_push.success',
        tags: EventBusGateway::Constants::DD_TAGS
      )

      subject.new.perform(participant_id, template_id)
    end
  end

  describe 'push notification creation' do
    let(:user_account_for_test) { create(:user_account, icn: mpi_profile.icn) }

    before do
      user_account_for_test
      allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
      allow(StatsD).to receive(:increment)
    end

    it 'creates EventBusGatewayPushNotification with correct attributes' do
      expect(EventBusGatewayPushNotification).to receive(:create!).with(
        user_account: user_account_for_test,
        template_id: template_id
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
        EventBusGateway::Constants::NOTIFY_SETTINGS.api_key
      ).and_return(va_notify_service)

      subject.new.perform(participant_id, template_id)
    end
  end

  describe 'ICN handling' do
    context 'when ICN is present' do
      before do
        user_account
        allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(StatsD).to receive(:increment)
      end

      it 'sends push notification with ICN' do
        expect(va_notify_service).to receive(:send_push).with(
          mobile_app: 'VA_FLAGSHIP_APP',
          recipient_identifier: { id_value: mpi_profile.icn, id_type: 'ICN' },
          template_id: template_id,
          personalisation: {}
        )

        subject.new.perform(participant_id, template_id)
      end
    end

    context 'when ICN is blank' do
      let(:mpi_profile_blank_icn) { build(:mpi_profile, icn: '') }
      let(:mpi_profile_response_blank_icn) { create(:find_profile_response, profile: mpi_profile_blank_icn) }

      before do
        allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response_blank_icn)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'raises error for missing ICN' do
        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error('Failed to fetch ICN')
      end

      it 'does not send push notification' do
        expect(va_notify_service).not_to receive(:send_push)

        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error('Failed to fetch ICN')
      end

      it 'does not create notification record' do
        expect(EventBusGatewayPushNotification).not_to receive(:create!)

        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error('Failed to fetch ICN')
      end

      it 'does not increment success metric' do
        expect(StatsD).not_to receive(:increment).with(/success/)

        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error('Failed to fetch ICN')
      end
    end

    context 'when ICN is nil' do
      let(:mpi_profile_nil_icn) { build(:mpi_profile, icn: nil) }
      let(:mpi_profile_response_nil_icn) { create(:find_profile_response, profile: mpi_profile_nil_icn) }

      before do
        allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response_nil_icn)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'raises error for missing ICN' do
        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error('Failed to fetch ICN')
      end
    end
  end

  describe 'edge cases' do
    context 'when mpi_profile is nil' do
      before do
        allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(nil)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'raises error for missing MPI profile' do
        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error('Failed to fetch MPI profile')
      end

      it 'does not send push notification' do
        expect(va_notify_service).not_to receive(:send_push)

        expect { subject.new.perform(participant_id, template_id) }
          .to raise_error('Failed to fetch MPI profile')
      end
    end
  end

  describe 'error handling' do
    context 'when notify client raises an error' do
      let(:notify_error) { StandardError.new('Notify service error') }

      before do
        user_account
        allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(va_notify_service).to receive(:send_push).and_raise(notify_error)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'records notification send failure' do
        expect_any_instance_of(described_class).to receive(:record_notification_send_failure).with(notify_error, 'Push')

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
        allow(VaNotify::Service).to receive(:new).with(EventBusGateway::Constants::NOTIFY_SETTINGS.api_key).and_return(va_notify_service)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(EventBusGatewayPushNotification).to receive(:create!).and_raise(creation_error)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'records notification send failure' do
        expect_any_instance_of(described_class).to receive(:record_notification_send_failure).with(creation_error, 'Push')

        expect { subject.new.perform(participant_id, template_id) }.to raise_error(creation_error)
      end
    end
  end
end
