# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::VAAppointments do
  let(:adapted_appointments) do
    file = File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments.json'))
    subject.parse(JSON.parse(file))
  end
  
  it 'returns a list of appointments at the expected size' do
    expect(adapted_appointments.size).to eq(10)
  end
  
  context 'with a booked VA appointment' do
    let(:booked_va) { adapted_appointments[0] }
    
    it 'has a type of VA' do
      expect(booked_va[:appointment_type]).to eq('VA')
    end
    
    it 'has a facility_id that matches the parent facility id' do
      expect(booked_va[:facility_id]).to eq('983')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_va[:facility_id]).to eq('CHY PC KILPATRICK')
    end
  end
  
  context 'with a booked VA appointment' do
    let(:cancelled_va) { adapted_appointments[1] }
  end
  
  context 'with a booked VA appointment' do
    let(:booked_video_home) { adapted_appointments[7] }
  end
  
  context 'with a booked VA appointment' do
    let(:booked_video_atlas) { adapted_appointments[8] }
  end
  
  context 'with a booked VA appointment' do
    let(:booked_video_gfe) { adapted_appointments[9] }
  end
end
