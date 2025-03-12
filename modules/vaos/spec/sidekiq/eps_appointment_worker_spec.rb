# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::EpsAppointmentWorker, type: :job do
  subject { described_class }

  let(:user) { build(:user, :vaos, :accountable) }
  let(:appointment_id) { '12345' }
  let(:service) { instance_double(Eps::AppointmentService) }
  let(:response) { OpenStruct.new(state: 'completed', appointmentDetails: OpenStruct.new(status: 'booked')) }

  before do
    Sidekiq::Job.clear_all
    allow(Eps::AppointmentService).to receive(:new).and_return(service)
  end

  describe '.perform_async' do
    it 'submits successfully' do
      expect do
        subject.perform_async(appointment_id, user)
      end.to change(subject.jobs, :size).by(1)
    end

    it 'calls get_appointment with the appointment_id' do
      allow(service).to receive(:get_appointment).with(appointment_id:).and_return(response)
      expect(service).to receive(:get_appointment).with(appointment_id:)
      subject.new.perform(appointment_id, user)
    end

    it 'retries if the appointment is not finished' do
      unfinished_response = OpenStruct.new(state: 'pending', appointmentDetails: OpenStruct.new(status: 'pending'))
      allow(service).to receive(:get_appointment).with(appointment_id:).and_return(unfinished_response)
      expect(subject).to receive(:perform_in).with(1.minute, appointment_id, user, 1)
      subject.new.perform(appointment_id, user)
    end

    it 'sends failure message after max retries' do
      unfinished_response = OpenStruct.new(state: 'pending', appointmentDetails: OpenStruct.new(status: 'pending'))
      allow(service).to receive(:get_appointment).with(appointment_id:).and_return(unfinished_response)
      expect(subject).to receive(:send_vanotify_message).with(success: false, error: 'Could not complete booking')
      subject.new.perform(appointment_id, user, 3)
    end
  end
end