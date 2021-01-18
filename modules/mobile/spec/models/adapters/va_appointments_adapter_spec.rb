# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::VAAppointments do
  let(:appointment_fixtures) do
    File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments.json'))
  end

  let(:adapted_appointments) do
    subject.parse(JSON.parse(appointment_fixtures, symbolize_names: true))[0]
  end

  let(:adapted_facilities) do
    subject.parse(JSON.parse(appointment_fixtures, symbolize_names: true))[1]
  end

  it 'returns a list of appointments at the expected size' do
    expect(adapted_appointments.size).to eq(10)
  end

  it 'returns a set of the facilities for the appointments' do
    expect(adapted_facilities).to eq(Set.new(['442']))
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
      expect(booked_va[:facility_id]).to eq('442')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_va[:healthcare_service]).to eq('CHY PC KILPATRICK')
    end

    it 'has a location with a name (address to be filled in by facilities api)' do
      expect(booked_va[:location].to_h).to eq(
        {
          name: 'CHEYENNE VAMC',
          address: {
            street: nil,
            city: nil,
            state: nil,
            zip_code: nil
          },
          lat: nil,
          long: nil,
          phone: {
            area_code: nil,
            number: nil,
            extension: nil
          },
          url: nil,
          code: nil
        }
      )
    end

    it 'has a duration' do
      expect(booked_va[:minutes_duration]).to eq(20)
    end

    it 'has a utc start date' do
      expect(booked_va[:start_date_utc]).to eq(DateTime.parse('Tue, 03 Nov 2020 16:00:00 +0000'))
    end

    it 'has a local start date' do
      expect(booked_va[:start_date_local]).to eq(DateTime.parse('Tue, 03 Nov 2020 09:00:00 MST -07:00'))
    end

    it 'has a booked status' do
      expect(booked_va[:status]).to eq('BOOKED')
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
      expect(cancelled_va[:facility_id]).to eq('442')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(cancelled_va[:healthcare_service]).to eq('CHY PC KILPATRICK')
    end

    it 'has a location with a name (address to be filled in by facilities api)' do
      expect(cancelled_va[:location].to_h).to eq(
        {
          name: 'CHEYENNE VAMC',
          address: {
            street: nil,
            city: nil,
            state: nil,
            zip_code: nil
          },
          lat: nil,
          long: nil,
          phone: {
            area_code: nil,
            number: nil,
            extension: nil
          },
          url: nil,
          code: nil
        }
      )
    end

    it 'has a nil duration' do
      expect(cancelled_va[:minutes_duration]).to be_nil
    end

    it 'has a utc start date' do
      expect(cancelled_va[:start_date_utc]).to eq(DateTime.parse('Tue, 03 Nov 2020 20:20:00 +0000'))
    end

    it 'has a local start date' do
      expect(cancelled_va[:start_date_local]).to eq(DateTime.parse('Tue, 03 Nov 2020 13:20:00 MST -07:00'))
    end

    it 'has a cancelled status' do
      expect(cancelled_va[:status]).to eq('CANCELLED')
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
      expect(booked_video_home[:facility_id]).to eq('442')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_home[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with a url and code' do
      expect(booked_video_home[:location].to_h).to eq(
        {
          name: 'CHEYENNE VAMC',
          address: {
            street: nil,
            city: nil,
            state: nil,
            zip_code: nil
          },
          lat: nil,
          long: nil,
          phone: {
            area_code: nil,
            number: nil,
            extension: nil
          },
          url: 'https://care2.evn.va.gov/vvc-app/?name=OG%2Ctesting+adhoc+video+visit&join=1&media=1&escalate=1&conference=VVC2520583@care2.evn.va.gov&pin=5364921#',
          code: '5364921#'
        }
      )
    end

    it 'has a duration' do
      expect(booked_video_home[:minutes_duration]).to eq(20)
    end

    it 'has a local start date' do
      expect(booked_video_home[:start_date_local]).to eq(DateTime.parse('2020-11-30 10:32:00.000 MST -07:00'))
    end

    it 'has a utc start date' do
      expect(booked_video_home[:start_date_utc]).to eq(DateTime.parse('2020-11-30T17:32:00+00:00'))
    end

    it 'has a status' do
      expect(booked_video_home[:status]).to eq('BOOKED')
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
      expect(booked_video_atlas[:facility_id]).to eq('442')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_atlas[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with an address and a code' do
      expect(booked_video_atlas[:location].to_h).to eq(
        {
          name: 'CHEYENNE VAMC',
          address: {
            street: '114 Dewey Ave',
            city: 'Eureka',
            state: 'MT',
            zip_code: '59917'
          },
          lat: nil,
          long: nil,
          phone: {
            area_code: nil,
            number: nil,
            extension: nil
          },
          url: nil,
          code: '7VBBCA'
        }
      )
    end

    it 'has a duration' do
      expect(booked_video_atlas[:minutes_duration]).to eq(30)
    end

    it 'has a utc start date' do
      expect(booked_video_atlas[:start_date_utc]).to eq(DateTime.parse('Thu, 23 Sep 2021 20:00:00 +0000'))
    end

    it 'has a local start date' do
      expect(booked_video_atlas[:start_date_local]).to eq(DateTime.parse('Thu, 23 Sep 2021 14:00:00 MDT -06:00'))
    end

    it 'has a booked status' do
      expect(booked_video_atlas[:status]).to eq('BOOKED')
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
      expect(booked_video_gfe[:facility_id]).to eq('442')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_gfe[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with a url and code' do
      expect(booked_video_gfe[:location].to_h).to eq(
        {
          name: 'CHEYENNE VAMC',
          address: {
            street: nil,
            city: nil,
            state: nil,
            zip_code: nil
          },
          lat: nil,
          long: nil,
          phone: {
            area_code: nil,
            number: nil,
            extension: nil
          },
          url: 'https://care2.evn.va.gov/vvc-app/?name=Reddy%2CVilasini&join=1&media=1&escalate=1&conference=VVC1012210@care2.evn.va.gov&pin=3527890#',
          code: '3527890#'
        }
      )
    end

    it 'has a duration' do
      expect(booked_video_gfe[:minutes_duration]).to eq(20)
    end

    it 'has a local start date' do
      expect(booked_video_gfe[:start_date_local]).to eq(DateTime.parse('2020-11-22 06:35:00.000 MST -07:00'))
    end

    it 'has a utc start date' do
      expect(booked_video_gfe[:start_date_utc]).to eq(DateTime.parse('2020-11-22T13:35:00.000+00:00'))
    end

    it 'has a booked status' do
      expect(booked_video_gfe[:status]).to eq('BOOKED')
    end
  end
end
