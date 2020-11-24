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

    it 'has a comment' do
      expect(booked_va[:comment]).to eq('RP test')
    end

    it 'has a facility_id that matches the parent facility id' do
      expect(booked_va[:facility_id]).to eq('983')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_va[:healthcare_service]).to eq('CHY PC KILPATRICK')
    end

    it 'has a location with a name (address to be filled in by facilities api)' do
      expect(booked_va[:location]).to eq(
        {
          name: 'CHYSHR-Cheyenne VA Medical Center',
          address: nil,
          phone: nil,
          url: nil,
          code: nil
        }
      )
    end

    it 'has a duration' do
      expect(booked_va[:minutes_duration]).to eq(20)
    end

    it 'has a start date' do
      expect(booked_va[:start_date]).to eq(DateTime.parse('2020-11-03T16:00:00.000+00:00'))
    end

    it 'has a booked status' do
      expect(booked_va[:status]).to eq('BOOKED')
    end

    it 'has a time zone' do
      expect(booked_va[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with a cancelled VA appointment' do
    let(:cancelled_va) { adapted_appointments[1] }

    it 'has a type of VA' do
      expect(cancelled_va[:appointment_type]).to eq('VA')
    end

    it 'does not have comment' do
      expect(cancelled_va[:comment]).to be_nil
    end

    it 'has a facility_id that matches the parent facility id' do
      expect(cancelled_va[:facility_id]).to eq('983')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(cancelled_va[:healthcare_service]).to eq('CHY PC KILPATRICK')
    end

    it 'has a location with a name (address to be filled in by facilities api)' do
      expect(cancelled_va[:location]).to eq(
        {
          name: 'CHYSHR-Cheyenne VA Medical Center',
          address: nil,
          phone: nil,
          url: nil,
          code: nil
        }
      )
    end

    it 'has a nil duration' do
      expect(cancelled_va[:minutes_duration]).to be_nil
    end

    it 'has a start date' do
      expect(cancelled_va[:start_date]).to eq(DateTime.parse('2020-11-03T20:20:00.000+00:00'))
    end

    it 'has a cancelled status' do
      expect(cancelled_va[:status]).to eq('CANCELLED')
    end

    it 'has a time zone' do
      expect(cancelled_va[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with a booked home video appointment' do
    let(:booked_video_home) { adapted_appointments[7] }

    it 'has a type of VA_VIDEO_CONNECT_HOME' do
      expect(booked_video_home[:appointment_type]).to eq('VA_VIDEO_CONNECT_HOME')
    end

    it 'does not have comment' do
      expect(booked_video_home[:comment]).to be_nil
    end

    it 'has a facility_id that matches the parent facility id' do
      expect(booked_video_home[:facility_id]).to eq('983')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_home[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with a url and code' do
      expect(booked_video_home[:location]).to eq(
        {
          name: 'CHYSHR-Cheyenne VA Medical Center',
          address: nil,
          phone: nil,
          url: 'https://care2.evn.va.gov/vvc-app/?name=OG%2Ctesting+adhoc+video+visit&join=1&media=1&escalate=1&conference=VVC2520583@care2.evn.va.gov&pin=5364921#',
          code: '5364921#'
        }
      )
    end

    it 'has a duration' do
      expect(booked_video_home[:minutes_duration]).to eq(20)
    end

    it 'has a start date' do
      expect(booked_video_home[:start_date]).to eq(DateTime.parse('2020-11-30T17:32:00+00:00'))
    end

    it 'has a status' do
      expect(booked_video_home[:status]).to eq('BOOKED')
    end

    it 'has a time zone' do
      expect(booked_video_home[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with a booked atlas appointment' do
    let(:booked_video_atlas) { adapted_appointments[8] }

    it 'has a type of VA' do
      expect(booked_video_atlas[:appointment_type]).to eq('VA_VIDEO_CONNECT_ATLAS')
    end

    it 'has no comment' do
      expect(booked_video_atlas[:comment]).to be_nil
    end

    it 'has a facility_id that matches the parent facility id' do
      expect(booked_video_atlas[:facility_id]).to eq('983')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_atlas[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with an address and a code' do
      expect(booked_video_atlas[:location]).to eq(
        {
          name: 'CHYSHR-Cheyenne VA Medical Center',
          address: {
            street: '114 Dewey Ave',
            city: 'Eureka',
            state: 'MT',
            zip_code: '59917',
            country: 'USA'
          },
          phone: nil,
          url: nil,
          code: '7VBBCA'
        }
      )
    end

    it 'has a duration' do
      expect(booked_video_atlas[:minutes_duration]).to eq(30)
    end

    it 'has a start date' do
      expect(booked_video_atlas[:start_date]).to eq(DateTime.parse('2021-09-23T20:00:00.000+00:00'))
    end

    it 'has a booked status' do
      expect(booked_video_atlas[:status]).to eq('BOOKED')
    end

    it 'has a time zone' do
      expect(booked_video_atlas[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with a booked video appointment on VA furnished equipment' do
    let(:booked_video_gfe) { adapted_appointments[9] }

    it 'has a type of VA' do
      expect(booked_video_gfe[:appointment_type]).to eq('VA_VIDEO_CONNECT_GFE')
    end

    it 'has a comment' do
      expect(booked_video_gfe[:comment]).to eq('Medication Review')
    end

    it 'has a facility_id that matches the parent facility id' do
      expect(booked_video_gfe[:facility_id]).to eq('983')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_gfe[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with a url and code' do
      expect(booked_video_gfe[:location]).to eq(
        {
          name: 'CHYSHR-Cheyenne VA Medical Center',
          address: nil,
          phone: nil,
          url: 'https://care2.evn.va.gov/vvc-app/?name=Reddy%2CVilasini&join=1&media=1&escalate=1&conference=VVC1012210@care2.evn.va.gov&pin=3527890#',
          code: '3527890#'
        }
      )
    end

    it 'has a duration' do
      expect(booked_video_gfe[:minutes_duration]).to eq(20)
    end

    it 'has a start date' do
      expect(booked_video_gfe[:start_date]).to eq(DateTime.parse('2020-11-22T13:35:00.000+00:00'))
    end

    it 'has a booked status' do
      expect(booked_video_gfe[:status]).to eq('BOOKED')
    end

    it 'has a time zone' do
      expect(booked_video_gfe[:time_zone]).to eq('America/Denver')
    end
  end
end
