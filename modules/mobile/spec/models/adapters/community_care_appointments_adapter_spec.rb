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

    it 'has a location with a name and address' do
      expect(booked_cc[:location].to_h).to eq(
        {
          name: 'Atlantic Medical Care',
          address: {
            street: '123 Main Street',
            city: 'Orlando',
            state: 'FL',
            zip_code: '32826'
          },
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

    it 'has a start date' do
      expect(booked_cc[:start_date]).to eq(DateTime.parse('2020-04-25T13:30:00.000-04:00'))
    end

    it 'has a offset of -4 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-14_400)
    end

    it 'has a booked status' do
      expect(booked_cc[:status]).to eq('BOOKED')
    end

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/New_York')
    end
  end

  context 'with a booked CC appointment in AKST' do
    let(:booked_cc) { adapted_appointments[1] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Anchorage')
    end

    it 'has a offset of -9 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-32_400)
    end
  end

  context 'with a booked CC appointment in AKDT' do
    let(:booked_cc) { adapted_appointments[2] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Anchorage')
    end

    it 'has a offset of -8 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-28_800)
    end
  end

  context 'with a booked CC appointment in AST' do
    let(:booked_cc) { adapted_appointments[3] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Argentina/San_Juan')
    end

    it 'has a offset of -4 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-14_400)
    end
  end

  context 'with a booked CC appointment in CDT' do
    let(:booked_cc) { adapted_appointments[4] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Chicago')
    end

    it 'has a offset of -6 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-21_600)
    end
  end

  context 'with a booked CC appointment in CST' do
    let(:booked_cc) { adapted_appointments[5] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Chicago')
    end

    it 'has a offset of -5 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-18_000)
    end
  end

  context 'with a booked CC appointment in EDT' do
    let(:booked_cc) { adapted_appointments[6] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/New_York')
    end

    it 'has a offset of -5 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-18_000)
    end
  end

  context 'with a booked CC appointment in EST' do
    let(:booked_cc) { adapted_appointments[7] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/New_York')
    end

    it 'has a offset of -4 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-14_400)
    end
  end

  context 'with a booked CC appointment in HST' do
    let(:booked_cc) { adapted_appointments[8] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('Pacific/Honolulu')
    end

    it 'has a offset of -10 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-36_000)
    end
  end

  context 'with a booked CC appointment in MDT' do
    let(:booked_cc) { adapted_appointments[9] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Denver')
    end

    it 'has a offset of -7 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-25_200)
    end
  end

  context 'with a booked CC appointment in MST' do
    let(:booked_cc) { adapted_appointments[10] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Denver')
    end

    it 'has a offset of -6 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-21_600)
    end
  end

  context 'with a booked CC appointment in PHST' do
    let(:booked_cc) { adapted_appointments[11] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('Asia/Manila')
    end

    it 'has a offset of +8 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(28_800)
    end
  end

  context 'with a booked CC appointment in PDT' do
    let(:booked_cc) { adapted_appointments[12] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Los_Angeles')
    end

    it 'has a offset of -8 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-28_800)
    end
  end

  context 'with a booked CC appointment in PST' do
    let(:booked_cc) { adapted_appointments[13] }

    it 'has the correct tz database timezone' do
      expect(booked_cc[:time_zone]).to eq('America/Los_Angeles')
    end

    it 'has a offset of -7 hours' do
      expect(booked_cc[:start_date].utc_offset).to eq(-25_200)
    end
  end
end
