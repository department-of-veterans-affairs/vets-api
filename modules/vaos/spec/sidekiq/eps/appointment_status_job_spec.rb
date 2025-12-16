# frozen_string_literal: true

require 'rails_helper'
require 'va_notify'

RSpec.describe Eps::AppointmentStatusJob, type: :job do
  subject(:worker) { described_class.new }

  let(:user) { build(:user, :loa3, vet360_id: '12345') }
  let(:appointment_id) { '12345' }
  let(:appointment_id_last4) { '2345' }
  let(:service) { instance_double(Eps::AppointmentService) }
  let(:response) { OpenStruct.new(state: 'completed', appointmentDetails: OpenStruct.new(status: 'booked')) }
  let(:unfinished_response) { OpenStruct.new(state: 'pending', appointmentDetails: OpenStruct.new(status: 'pending')) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(User).to receive(:find).with(user.uuid).and_return(user)
    Sidekiq::Job.clear_all
    Rails.cache.clear
    redis_client = Eps::RedisClient.new

    redis_client.store_appointment_data(
      uuid: user.uuid,
      appointment_id:,
      email: user.va_profile_email
    )

    allow(Eps::AppointmentService).to receive(:new).and_return(service)
    allow(Eps::AppointmentStatusEmailJob).to receive(:perform_async)
  end

  after do
    Rails.cache.clear
  end

  describe '.perform_async' do
    it 'submits successfully' do
      expect do
        described_class.perform_async(user.uuid, appointment_id_last4)
      end.to change(described_class.jobs, :size).by(1)
    end

    it 'calls get_appointment with the appointment_id' do
      allow(service).to receive(:get_appointment).with(appointment_id:).and_return(response)
      expect(service).to receive(:get_appointment).with(appointment_id:)
      worker.perform(user.uuid, appointment_id_last4)
    end

    context 'when the appointment is not finished' do
      before do
        allow(service).to receive(:get_appointment).with(appointment_id:).and_return(unfinished_response)
      end

      it 'retries the job' do
        expect(described_class).to receive(:perform_in).with(1.minute, user.uuid, appointment_id_last4, 1)
        worker.perform(user.uuid, appointment_id_last4)
      end

      it 'sends failure message after max retries' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.appointment_status_check.failure',
          tags: ['service:community_care_appointments']
        )

        expect(Eps::AppointmentStatusEmailJob).to receive(:perform_async).with(
          user.uuid,
          appointment_id_last4,
          Eps::AppointmentStatusJob::ERROR_MESSAGE
        )
        worker.perform(user.uuid, appointment_id_last4, Eps::AppointmentStatusJob::MAX_RETRIES)
      end
    end

    context 'when the appointment is not found' do
      before do
        allow(service).to receive(:get_appointment).with(appointment_id:).and_raise(
          Common::Exceptions::BackendServiceException.new(nil, {}, 404, 'Appointment not found')
        )
      end

      it 'sends failure message after max retries' do
        expect(Eps::AppointmentStatusEmailJob).to receive(:perform_async).with(
          user.uuid,
          appointment_id_last4,
          Eps::AppointmentStatusJob::ERROR_MESSAGE
        )
        worker.perform(user.uuid, appointment_id_last4, Eps::AppointmentStatusJob::MAX_RETRIES)
      end
    end

    context 'when the upstream service returns a 500 error' do
      before do
        allow(service).to receive(:get_appointment).with(appointment_id:).and_raise(
          Common::Exceptions::BackendServiceException.new(nil, {}, 500, 'Internal server error')
        )
      end

      it 'sends failure message after max retries' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.appointment_status_check.failure',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: Eps::AppointmentStatusJob failed to get appointment status',
          { user_uuid: user.uuid, appointment_id_last4: }
        )
        expect(Eps::AppointmentStatusEmailJob).to receive(:perform_async).with(
          user.uuid,
          appointment_id_last4,
          Eps::AppointmentStatusJob::ERROR_MESSAGE
        )
        worker.perform(user.uuid, appointment_id_last4, Eps::AppointmentStatusJob::MAX_RETRIES)
      end
    end

    context 'when Redis data is missing or incomplete' do
      before do
        # Clear the Redis data for this specific test
        Rails.cache.clear
      end

      it 'logs error and returns early' do
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: Eps::AppointmentStatusJob missing or incomplete Redis data',
          { user_uuid: user.uuid, appointment_id_last4:, appointment_data: nil }.to_json
        )
        expect(StatsD).to receive(:increment).with(
          'api.vaos.appointment_status_check.failure',
          tags: ['service:community_care_appointments']
        )
        worker.perform(user.uuid, appointment_id_last4)
      end
    end
  end
end
