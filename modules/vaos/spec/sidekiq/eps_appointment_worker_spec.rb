# frozen_string_literal: true

require 'rails_helper'
require 'va_notify'

RSpec.describe Eps::EpsAppointmentWorker, type: :job do
  subject(:worker) { described_class.new }

  let(:user) { build(:user) }
  let(:appointment_id) { '12345' }
  let(:service) { instance_double(Eps::AppointmentService) }
  let(:response) { OpenStruct.new(state: 'completed', appointmentDetails: OpenStruct.new(status: 'booked')) }
  let(:unfinished_response) { OpenStruct.new(state: 'pending', appointmentDetails: OpenStruct.new(status: 'pending')) }
  let(:va_notify_service) { instance_double(VaNotify::Service) }

  before do
    Sidekiq::Job.clear_all
    allow(Eps::AppointmentService).to receive(:new).and_return(service)
    allow(VaNotify::Service).to receive(:new)
      .with(Settings.vanotify.services.va_gov.api_key)
      .and_return(va_notify_service)
  end

  describe '.perform_async' do
    it 'submits successfully' do
      expect do
        described_class.perform_async(appointment_id, user)
      end.to change(described_class.jobs, :size).by(1)
    end

    it 'calls get_appointment with the appointment_id' do
      allow(service).to receive(:get_appointment).with(appointment_id:).and_return(response)
      expect(service).to receive(:get_appointment).with(appointment_id:)
      worker.perform(appointment_id, user)
    end

    context 'when the appointment is not finished' do
      before do
        allow(service).to receive(:get_appointment).with(appointment_id:).and_return(unfinished_response)
      end

      it 'retries the job' do
        expect(described_class).to receive(:perform_in).with(1.minute, appointment_id, user, 1)
        worker.perform(appointment_id, user)
      end

      it 'sends failure message after max retries' do
        expect(va_notify_service).to receive(:send_email).with(
          email_address: user.va_profile_email,
          template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
          parameters: {
            'error' => 'Could not complete booking'
          }
        )
        worker.perform(appointment_id, user, Eps::EpsAppointmentWorker::MAX_RETRIES)
      end
    end

    context 'when the appointment is not found' do
      before do
        allow(service).to receive(:get_appointment).with(appointment_id:).and_raise(
          Common::Exceptions::BackendServiceException.new(nil, {}, 404, 'Appointment not found')
        )
      end

      it 'sends failure message after max retries' do
        expect(va_notify_service).to receive(:send_email).with(
          email_address: user.va_profile_email,
          template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
          parameters: {
            'error' => 'Service error, please contact support'
          }
        )
        worker.perform(appointment_id, user, Eps::EpsAppointmentWorker::MAX_RETRIES)
      end
    end

    context 'when the upstream service returns a 500 error' do
      before do
        allow(service).to receive(:get_appointment).with(appointment_id:).and_raise(
          Common::Exceptions::BackendServiceException.new(nil, {}, 500, 'Internal server error')
        )
      end

      it 'sends failure message after max retries' do
        expect(va_notify_service).to receive(:send_email).with(
          email_address: user.va_profile_email,
          template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
          parameters: {
            'error' => 'Service error, please contact support'
          }
        )
        worker.perform(appointment_id, user, Eps::EpsAppointmentWorker::MAX_RETRIES)
      end
    end

    describe '#send_vanotify_message' do
      it 'sends email notification' do
        expect(va_notify_service).to receive(:send_email).with(
          email_address: user.va_profile_email,
          template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
          parameters: {
            'error' => nil
          }
        )
        worker.send(:send_vanotify_message, user:)
      end
    end
  end
end
