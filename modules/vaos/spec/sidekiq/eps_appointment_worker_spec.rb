# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::EpsAppointmentWorker, type: :job do
  subject(:worker) { described_class.new }

  let(:user) { build(:user) }
  let(:appointment_id) { '12345' }
  let(:service) { instance_double(Eps::AppointmentService) }
  let(:response) { OpenStruct.new(state: 'completed', appointmentDetails: OpenStruct.new(status: 'booked')) }
  let(:unfinished_response) { OpenStruct.new(state: 'pending', appointmentDetails: OpenStruct.new(status: 'pending')) }

  before do
    Sidekiq::Job.clear_all
    allow(Eps::AppointmentService).to receive(:new).and_return(service)
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
        # rubocop:disable RSpec/SubjectStub
        expect(worker).to receive(:send_vanotify_message).with(success: false, error: 'Could not complete booking')
        worker.perform(appointment_id, user, Eps::EpsAppointmentWorker::MAX_RETRIES)
        # rubocop:enable RSpec/SubjectStub
      end
    end
  end
end