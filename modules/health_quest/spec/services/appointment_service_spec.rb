# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::AppointmentService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :health_quest) }

  before do
    Flipper.enable('show_healthcare_experience_questionnaire')
    allow_any_instance_of(HealthQuest::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '#get_appointment_by_id' do
    let(:appointment) { subject.get_appointment_by_id(132) }

    it 'is a Hash' do
      expect(appointment).to be_a(Hash)
    end

    it 'has a data key of type OpenStruct' do
      expect(appointment[:data]).to be_a(OpenStruct)
    end

    it 'data openstruct object has expected keys' do
      data = appointment[:data]
      attributes = %i[
        id start_date clinic_id clinic_friendly_name facility_id sta6aid
        station_name patient_icn community_care vds_appointments
      ]

      attributes.each do |attr|
        expect(data.respond_to?(attr)).to be(true)
      end
    end
  end
end
