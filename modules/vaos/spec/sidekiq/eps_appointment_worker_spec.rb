# frozen_string_literal: true

require 'rails_helper'
require 'va_notify'

RSpec.describe Eps::EpsAppointmentWorker, type: :job do
  subject(:worker) { described_class.new }

  let(:user) { build(:user, :loa3) }
  let(:appointment_id) { '12345' }
  let(:service) { instance_double(Eps::AppointmentService) }
  let(:response) { OpenStruct.new(state: 'completed', appointmentDetails: OpenStruct.new(status: 'booked')) }
  let(:unfinished_response) { OpenStruct.new(state: 'pending', appointmentDetails: OpenStruct.new(status: 'pending')) }
  let(:va_notify_service) { instance_double(VaNotify::Service) }

  before do
    Sidekiq::Job.clear_all
    allow(User).to receive(:find).with(user.uuid).and_return(user)
    allow(Eps::AppointmentService).to receive(:new).and_return(service)
    allow(VaNotify::Service).to receive(:new)
      .with(Settings.vanotify.services.va_gov.api_key)
      .and_return(va_notify_service)
    allow(Rails.logger).to receive(:error)
  end

  describe '.perform_async' do
    it 'submits successfully' do
      expect do
        described_class.perform_async(appointment_id, user.uuid)
      end.to change(described_class.jobs, :size).by(1)
    end

    it 'calls get_appointment with the appointment_id' do
      allow(service).to receive(:get_appointment).with(appointment_id:).and_return(response)
      expect(service).to receive(:get_appointment).with(appointment_id:)
      worker.perform(appointment_id, user.uuid)
    end

    context 'when the appointment is not finished' do
      before do
        allow(service).to receive(:get_appointment).with(appointment_id:).and_return(unfinished_response)
      end

      it 'retries the job' do
        expect(described_class).to receive(:perform_in).with(1.minute, appointment_id, user.uuid, 1)
        worker.perform(appointment_id, user.uuid)
      end

      it 'sends failure message after max retries' do
        expect(va_notify_service).to receive(:send_email).with(
          email_address: user.va_profile_email,
          template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
          parameters: {
            'error' => 'Could not complete booking'
          }
        )
        worker.perform(appointment_id, user.uuid, Eps::EpsAppointmentWorker::MAX_RETRIES)
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
        worker.perform(appointment_id, user.uuid, Eps::EpsAppointmentWorker::MAX_RETRIES)
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
        worker.perform(appointment_id, user.uuid, Eps::EpsAppointmentWorker::MAX_RETRIES)
      end
    end

    context 'when user is not found' do
      before do
        allow(User).to receive(:find).with('missing-uuid').and_return(nil)
      end

      it 'logs an error and does not send notification' do
        expect(va_notify_service).not_to receive(:send_email)
        expect(Rails.logger).to receive(:error).with(/EpsAppointmentWorker FAILED for user UUID: missing-uuid: User not found/)
        worker.perform(appointment_id, 'missing-uuid')
      end
    end

    context 'when user email is missing' do
      before do
        user_without_email = build(:user, :loa3)
        allow(user_without_email).to receive(:va_profile_email).and_return(nil)
        allow(User).to receive(:find).with('user-without-email').and_return(user_without_email)
      end

      it 'logs an error and does not send notification' do
        expect(va_notify_service).not_to receive(:send_email)
        expect(Rails.logger).to receive(:error).with(/EpsAppointmentWorker FAILED for user UUID: user-without-email: Email not found for user/)
        worker.perform(appointment_id, 'user-without-email')
      end
    end

    context 'when a standard error occurs' do
      before do
        allow(service).to receive(:get_appointment).with(appointment_id:).and_raise(
          StandardError.new('An error occurred processing your appointment')
        )
      end

      it 'logs the error with worker failure message and user UUID' do
        allow(va_notify_service).to receive(:send_email) # Allow the notification to be sent
        expect(Rails.logger).to receive(:error).with(/EpsAppointmentWorker FAILED for user UUID: #{user.uuid}: StandardError/)
        worker.perform(appointment_id, user.uuid)
      end

      it 'sends a generic error message to the user' do
        expect(va_notify_service).to receive(:send_email).with(
          email_address: user.va_profile_email,
          template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
          parameters: {
            'error' => 'An error occurred processing your appointment'
          }
        )
        worker.perform(appointment_id, user.uuid)
      end
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
      worker.send(:send_vanotify_message, email: user.va_profile_email)
    end
  end
end
