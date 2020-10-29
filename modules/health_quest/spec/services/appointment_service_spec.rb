# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::AppointmentService do
  let(:user) { build(:user, :health_quest) }
  subject { described_class.new(user) }

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

    it 'data has relevant keys' do
      expect(appointment[:data].respond_to?(:id)).to be(true)
      expect(appointment[:data].respond_to?(:start_date)).to be(true)
      expect(appointment[:data].respond_to?(:clinic_id)).to be(true)
      expect(appointment[:data].respond_to?(:clinic_friendly_name)).to be(true)
      expect(appointment[:data].respond_to?(:facility_id)).to be(true)
      expect(appointment[:data].respond_to?(:sta6aid)).to be(true)
      expect(appointment[:data].respond_to?(:station_name)).to be(true)
      expect(appointment[:data].respond_to?(:patient_icn)).to be(true)
      expect(appointment[:data].respond_to?(:community_care)).to be(true)
      expect(appointment[:data].respond_to?(:vds_appointments)).to be(true)
    end

    it 'has pagination information' do
      expect(appointment[:meta][:pagination][:current_page]).to eq(0)
      expect(appointment[:meta][:pagination][:per_page]).to eq(0)
      expect(appointment[:meta][:pagination][:total_pages]).to eq(0)
      expect(appointment[:meta][:pagination][:total_entries]).to eq(0)
    end
  end
end
