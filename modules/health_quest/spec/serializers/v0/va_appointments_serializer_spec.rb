# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::V0::VAAppointmentsSerializer do
  subject { described_class.new(appt[:data], meta: appt[:meta]) }

  let(:klass) { described_class }
  let(:user) { build(:user, :health_quest) }
  let(:appt_service) { HealthQuest::AppointmentService.new(user) }
  let(:appt_body) { appt_service.mock_appointment }
  let(:appt_response) { double('Faraday::Response', body: appt_body[:data]) }
  let(:appt) { appt_service.get_appointment_by_id(132) }

  before do
    allow_any_instance_of(HealthQuest::UserService).to receive(:session).and_return('stubbed_token')
    allow_any_instance_of(HealthQuest::AppointmentService).to receive(:perform).and_return(appt_response)
  end

  describe 'subject type' do
    it 'is a HealthQuest::V0::VAAppointmentsSerializer' do
      expect(subject).to be_a(HealthQuest::V0::VAAppointmentsSerializer)
    end
  end

  describe 'included' do
    it 'includes FastJsonapi::ObjectSerializer' do
      expect(klass).to include(FastJsonapi::ObjectSerializer)
    end
  end

  describe 'KEY #data' do
    it 'has data key' do
      expect(subject.serializable_hash.key?(:data)).to be(true)
    end

    it 'data has attributes' do
      expect(subject.serializable_hash[:data][:attributes].keys).to eq(
        %i[start_date sta6aid clinic_id clinic_friendly_name facility_id community_care patient_icn vds_appointments
           vvs_appointments]
      )
    end

    it 'ignores patient id for vvs_appointments' do
      vvs_appointment = subject.serializable_hash.dig(:data, :attributes, :vvs_appointments)
      patient = vvs_appointment.first['patients'].first

      expect(patient['id']).to eq(nil)
    end

    it 'ignores provider id for vvs_appointments' do
      vvs_appointment = subject.serializable_hash.dig(:data, :attributes, :vvs_appointments)
      provider = vvs_appointment.first['providers'].first

      expect(provider['id']).to eq(nil)
    end
  end

  describe '.set_id' do
    it 'responds to set_id' do
      expect(klass.respond_to?(:set_id)).to eq(true)
    end
  end

  describe '.set_type' do
    it 'responds to set_type' do
      expect(klass.respond_to?(:set_type)).to eq(true)
    end
  end

  describe '.attributes' do
    it 'responds to attributes' do
      expect(klass.respond_to?(:attributes)).to eq(true)
    end
  end

  describe '.attribute' do
    it 'responds to attribute' do
      expect(klass.respond_to?(:attribute)).to eq(true)
    end
  end
end
