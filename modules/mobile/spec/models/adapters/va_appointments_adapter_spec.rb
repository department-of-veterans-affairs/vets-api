# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::VAAppointments do
  let(:appointment_fixtures) do
    File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments.json'))
  end

  let(:adapted_appointments) do
    subject.parse(JSON.parse(appointment_fixtures, symbolize_names: true))
  end

  it 'returns a list of appointments at the expected size' do
    expect(adapted_appointments.size).to eq(10)
  end

  it 'sets appointment request specific values' do
    is_pending = adapted_appointments.map(&:is_pending).uniq
    proposed_times = adapted_appointments.map(&:proposed_times).uniq
    type_of_care = adapted_appointments.map(&:type_of_care).uniq
    patient_phone_number = adapted_appointments.map(&:patient_phone_number).uniq
    patient_email = adapted_appointments.map(&:patient_email).uniq
    best_time_to_call = adapted_appointments.map(&:best_time_to_call).uniq
    friendly_location_name = adapted_appointments.map(&:friendly_location_name).uniq

    expect(is_pending).to eq([false])
    expect(proposed_times).to eq([nil])
    expect(type_of_care).to eq([nil])
    expect(patient_phone_number).to eq([nil])
    expect(patient_email).to eq([nil])
    expect(best_time_to_call).to eq([nil])
    expect(friendly_location_name).to eq([nil])
  end

  context 'with a booked VA appointment' do
    let(:booked_va) { adapted_appointments[0] }

    it 'has an id' do
      expect(booked_va[:id]).to eq('202006031600983000030800000000000000')
    end

    it 'has a cancel id of the encoded cancel params' do
      expect(booked_va[:cancel_id]).to eq('MzA4OzIwMjAxMTAzLjA5MDAwMDs0NDI7R3JlZW4gVGVhbSBDbGluaWMx')
    end

    it 'has a type of VA' do
      expect(booked_va[:appointment_type]).to eq('VA')
    end

    it 'has a comment' do
      expect(booked_va[:comment]).to eq('RP test')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_va[:healthcare_service]).to eq('Green Team Clinic1')
    end

    it 'has a location with a name (address to be filled in by facilities api)' do
      expect(booked_va[:location].to_h).to eq(
        {
          id: '442',
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

    it 'has a time zone' do
      expect(booked_va[:time_zone]).to eq('America/Denver')
    end

    it 'has a vetext id' do
      expect(booked_va[:vetext_id]).to eq('308;20201103.090000')
    end

    it 'has a facility_id' do
      expect(booked_va[:facility_id]).to eq('442')
    end

    it 'has a sta6aid' do
      expect(booked_va[:sta6aid]).to eq('442')
    end
  end

  context 'with a cancelled VA appointment' do
    let(:cancelled_va) { adapted_appointments[1] }

    it 'has an id' do
      expect(cancelled_va[:id]).to eq('202006032020983000030800000000000000')
    end

    it 'does not have a cancel id' do
      expect(cancelled_va[:cancel_id]).to be_nil
    end

    it 'has a type of VA' do
      expect(cancelled_va[:appointment_type]).to eq('VA')
    end

    it 'does not have comment' do
      expect(cancelled_va[:comment]).to be_nil
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(cancelled_va[:healthcare_service]).to eq('Green Team Clinic1')
    end

    it 'has a location with a name (address to be filled in by facilities api)' do
      expect(cancelled_va[:location].to_h).to eq(
        {
          id: '442',
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

    it 'has a time zone' do
      expect(cancelled_va[:time_zone]).to eq('America/Denver')
    end

    it 'has a facility_id' do
      expect(cancelled_va[:facility_id]).to eq('442')
    end

    it 'has a sta6aid' do
      expect(cancelled_va[:sta6aid]).to eq('442')
    end
  end

  context 'with a booked home video appointment' do
    let(:booked_video_home) { adapted_appointments[7] }

    it 'has an id' do
      expect(booked_video_home[:id]).to eq('202006111600983000045500000000000000')
    end

    it 'does not have a cancel id' do
      expect(booked_video_home[:cancel_id]).to be_nil
    end

    it 'has a type of VA_VIDEO_CONNECT_HOME' do
      expect(booked_video_home[:appointment_type]).to eq('VA_VIDEO_CONNECT_HOME')
    end

    it 'does not have comment' do
      expect(booked_video_home[:comment]).to be_nil
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_home[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with a url and code' do
      expect(booked_video_home[:location].to_h).to eq(
        {
          id: '442',
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

    it 'has a time zone' do
      expect(booked_video_home[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with a booked atlas appointment' do
    let(:booked_video_atlas) { adapted_appointments[8] }

    it 'has an id' do
      expect(booked_video_atlas[:id]).to eq('202006141600983000094500000000000000')
    end

    it 'does not have a cancel id' do
      expect(booked_video_atlas[:cancel_id]).to be_nil
    end

    it 'has a type of VA' do
      expect(booked_video_atlas[:appointment_type]).to eq('VA_VIDEO_CONNECT_ATLAS')
    end

    it 'has no comment' do
      expect(booked_video_atlas[:comment]).to be_nil
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_atlas[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with an address and a code' do
      expect(booked_video_atlas[:location].to_h).to eq(
        {
          id: '442',
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

    it 'has a time zone' do
      expect(booked_video_atlas[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with a booked video appointment on VA furnished equipment' do
    let(:booked_video_gfe) { adapted_appointments[9] }

    it 'has an id' do
      expect(booked_video_gfe[:id]).to eq('202006151200984000118400000000000000')
    end

    it 'does not have a cancel id' do
      expect(booked_video_gfe[:cancel_id]).to be_nil
    end

    it 'has a type of VA' do
      expect(booked_video_gfe[:appointment_type]).to eq('VA_VIDEO_CONNECT_GFE')
    end

    it 'has a comment' do
      expect(booked_video_gfe[:comment]).to eq('Medication Review')
    end

    it 'has a healthcare_service that matches the clinic name' do
      expect(booked_video_gfe[:healthcare_service]).to eq('CHEYENNE VAMC')
    end

    it 'has a location with a url and code' do
      expect(booked_video_gfe[:location].to_h).to eq(
        {
          id: '442',
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

    it 'has a time zone' do
      expect(booked_video_gfe[:time_zone]).to eq('America/Denver')
    end
  end

  context 'with appointments that have a missing status' do
    let(:appointment_fixtures_missing_status) do
      File.read(
        Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments_missing_status.json')
      )
    end

    let(:adapted_appointments_missing_status) do
      subject.parse(JSON.parse(appointment_fixtures_missing_status, symbolize_names: true))
    end

    context 'with  past appointment' do
      before { Timecop.freeze(Time.zone.parse('2021-01-13')) }

      after { Timecop.return }

      let(:booked_va_hidden_status) { adapted_appointments_missing_status[2] }

      it 'does not include a hidden status' do
        expect(booked_va_hidden_status.to_hash).to include(
          {
            status: 'BOOKED'
          }
        )
      end
    end

    context 'with a future appointment' do
      before { Timecop.freeze(Time.zone.parse('2021-01-15')) }

      after { Timecop.return }

      let(:booked_va_hidden_status) { adapted_appointments_missing_status[2] }

      it 'includes a hidden status' do
        expect(booked_va_hidden_status.to_hash).to include(
          {
            status: 'HIDDEN'
          }
        )
      end
    end
  end

  context 'with a list that include covid vaccine appointments' do
    let(:appointment_fixtures) do
      File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments_covid.json'))
    end

    let(:adapted_appointments) do
      subject.parse(JSON.parse(appointment_fixtures, symbolize_names: true))
    end

    let(:covid_vaccine_va) { adapted_appointments[0] }
    let(:non_covid_vaccine_va) { adapted_appointments[1] }

    it 'returns a list of appointments at the expected size' do
      expect(adapted_appointments.size).to eq(5)
    end

    it 'labels covid vaccine appointments correctly' do
      expect(covid_vaccine_va[:is_covid_vaccine]).to eq(true)
    end

    it 'labels non covid vaccine appointments correctly' do
      expect(non_covid_vaccine_va[:appointment_type]).to eq('VA')
      expect(non_covid_vaccine_va[:is_covid_vaccine]).to eq(false)
    end
  end

  context 'with a VA appointment that has a missing friendly name' do
    let(:missing_friendly_name) { adapted_appointments[3] }

    it 'uses the VDS clinic name' do
      expect(missing_friendly_name[:healthcare_service]).to eq('CHY PC CASSIDY')
    end
  end

  context 'with appointments that have different facility and station ids' do
    let(:appointment_facility_station_ids_json) do
      File.read(
        Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'va_appointments_sta6aid.json')
      )
    end

    let(:appointment_facility_station_ids) do
      subject.parse(JSON.parse(appointment_facility_station_ids_json, symbolize_names: true))
    end

    context 'with an appointment that has different ids' do
      let(:appointment_different_ids) { appointment_facility_station_ids.first }

      it 'has the expected facility id' do
        expect(appointment_different_ids.facility_id).to eq('442')
      end

      it 'has the expected sta6aid' do
        expect(appointment_different_ids.sta6aid).to eq('442GC')
      end
    end

    context 'with an appointment that has the same id for both' do
      let(:appointment_same_ids) { appointment_facility_station_ids.last }

      it 'has the expected facility id' do
        expect(appointment_same_ids.facility_id).to eq('442')
      end

      it 'has the expected sta6aid' do
        expect(appointment_same_ids.sta6aid).to eq('442')
      end
    end
  end
end
