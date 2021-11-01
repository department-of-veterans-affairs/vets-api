# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::CommunityCareAppointments do
  let(:adapted_appointments) do
    file = File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'cc_appointments.json'))
    subject.parse(JSON.parse(file, symbolize_names: true))
  end

  it 'returns a list of appointments at the expected size' do
    expect(adapted_appointments.size).to eq(17)
  end

  context 'with a booked CC appointment' do
    let(:booked_cc) { adapted_appointments[0] }

    it 'has a type of COMMUNITY_CARE' do
      expect(booked_cc[:appointment_type]).to eq('COMMUNITY_CARE')
    end

    it 'has a location with a name, address, and phone number' do
      expect(booked_cc[:location].to_h).to eq(
        {
          id: nil,
          name: 'Atlantic Medical Care',
          address: {
            street: '123 Main Street',
            city: 'Orlando',
            state: 'FL',
            zip_code: '32826'
          },
          lat: nil,
          long: nil,
          phone: {
            area_code: '407',
            number: '555-1212',
            extension: nil
          },
          url: nil,
          code: nil
        }
      )
    end

    it 'has a comment' do
      expect(booked_cc[:comment]).to eq('Please arrive 15 minutes ahead of appointment.')
    end

    it 'does not have a facility id' do
      expect(booked_cc[:facility_id]).to be_nil
    end

    it 'has a healthcare_service that matches the provider practice' do
      expect(booked_cc[:healthcare_service]).to eq('Atlantic Medical Care')
    end

    it 'has a duration' do
      expect(booked_cc[:minutes_duration]).to eq(60)
    end

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc]).to eq(DateTime.parse('2020-04-25T13:30:00.000-04:00'))
    end

    it 'has a booked status' do
      expect(booked_cc[:status]).to eq('BOOKED')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/New_York')
    end
  end

  context 'with a booked CC appointment in AKST' do
    let(:booked_cc) { adapted_appointments[1] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-12-20 23:15:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-12-20 14:15:00 -0900')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Anchorage')
    end
  end

  context 'with a booked CC appointment in AKDT' do
    let(:booked_cc) { adapted_appointments[2] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-04-20 22:15:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-04-20 14:15:00 -0800')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Anchorage')
    end
  end

  context 'with a booked CC appointment in AST' do
    let(:booked_cc) { adapted_appointments[3] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-12-22 22:20:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-12-22 19:20:00 -0300')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Argentina/San_Juan')
    end
  end

  context 'with a booked CC appointment in CDT' do
    let(:booked_cc) { adapted_appointments[4] }

    it 'has a offset of -6 hours' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-04-24 02:00:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-04-23 21:00:00 -0500')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Chicago')
    end
  end

  context 'with a booked CC appointment in CST' do
    let(:booked_cc) { adapted_appointments[5] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-12-01 20:13:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-12-01 14:13:00 -0600')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Chicago')
    end
  end

  context 'with a booked CC appointment in EDT' do
    let(:booked_cc) { adapted_appointments[6] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-05-13 22:11:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-05-13 18:11:00 -0400')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/New_York')
    end
  end

  context 'with a booked CC appointment in EST' do
    let(:booked_cc) { adapted_appointments[7] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-12-10 01:00:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-12-09 20:00:00 -0500')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/New_York')
    end
  end

  context 'with a booked CC appointment in HST' do
    let(:booked_cc) { adapted_appointments[8] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-12-15 01:00:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-12-14 15:00:00 -1000')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('Pacific/Honolulu')
    end
  end

  context 'with a booked CC appointment in MDT' do
    let(:booked_cc) { adapted_appointments[9] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-05-24 01:31:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-05-23 19:31:00 -0600')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with a booked CC appointment in MST' do
    let(:booked_cc) { adapted_appointments[10] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-12-06 02:07:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-12-05 19:07:00 -0700')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with a booked CC appointment in PHST' do
    let(:booked_cc) { adapted_appointments[11] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-12-12 06:00:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-12-12 14:00:00 +0800')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('Asia/Manila')
    end
  end

  context 'with a booked CC appointment in PDT' do
    let(:booked_cc) { adapted_appointments[12] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-06-21 03:00:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-06-20 20:00:00 -0700')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Los_Angeles')
    end
  end

  context 'with a booked CC appointment in PST' do
    let(:booked_cc) { adapted_appointments[13] }

    it 'has a utc start date' do
      expect(booked_cc[:start_date_utc].to_s).to eq('2020-12-17 22:30:00 UTC')
    end

    it 'has a local start date' do
      expect(booked_cc[:start_date_local].to_s).to eq('2020-12-17 14:30:00 -0800')
    end

    it 'has a time_zone' do
      expect(booked_cc[:time_zone]).to eq('America/Los_Angeles')
    end
  end
end
