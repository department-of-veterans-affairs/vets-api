# frozen_string_literal: true

require 'rails_helper'

describe Eps::AppointmentService do
  subject(:service) { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }
  let(:successful_appt_response) do
    double('Response', status: 200, body: { 'count' => 1,
                                            'appointments' => [
                                              {
                                                'id' => 'test-id',
                                                'state' => 'booked',
                                                'patientId' => patient_id
                                              }
                                            ] })
  end
  let(:patient_id) { 'test-patient-id' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  describe 'get_appointments' do
    before do
      allow(Rails.cache).to receive(:fetch).and_return(memory_store)
      Rails.cache.clear
    end

    context 'when requesting appointments for a given patient_id' do
      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(successful_appt_response)
      end

      it 'returns the appointments scheduled' do
        exp_response = OpenStruct.new(successful_appt_response.body)

        expect(service.get_appointments(patient_id:)).to eq(exp_response)
      end
    end

    context 'when include[:eps] is true' do
      let(:eps_appointments) do
        [
          OpenStruct.new(id: 'eps-test-id', state: 'booked', patientId: patient_id)
        ]
      end

      before do
        allow(service).to receive(:eps_appointments).and_return(eps_appointments)
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(successful_appt_response)
      end

      it 'merges eps_appointments with vaos appointments' do
        exp_response = OpenStruct.new(
          'count' => 2,
          'appointments' => [
            { 'id' => 'eps-test-id', 'state' => 'booked', 'patientId' => patient_id },
            { 'id' => 'test-id', 'state' => 'booked', 'patientId' => patient_id }
          ]
        )

        expect(service.get_appointments(patient_id:, include: { eps: true })).to eq(exp_response)
      end
    end

    context 'when the endpoint fails to return appointments' do
      let(:failed_appt_response) do
        double('Response', status: 500, body: 'Unknown service exception')
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_appt_response.status,
                                                        failed_appt_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'throws exception' do
        expect { service.get_appointments(patient_id:) }.to raise_error(Common::Exceptions::BackendServiceException,
                                                                        /VA900/)
      end
    end
  end
end
