# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::AppointmentRequests do
  let(:appointment_fixtures) do
    File.read(Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'appointment_requests.json'))
  end
  let(:data) do
    parsed = JSON.parse(appointment_fixtures, symbolize_names: true)
    parsed.map { |request| OpenStruct.new(request) }
  end
  let(:adapted_appointment_requests) do
    subject.parse(data)
  end
  let(:va_appointment_requests) { adapted_appointment_requests[0] }
  let(:cc_appointment_requests) { adapted_appointment_requests[1] }
  let(:all_appointment_requests) { [va_appointment_requests + cc_appointment_requests].flatten }
  let(:booked_request_id) { '8a48dea06c84a667016c866de87c000b' }
  let(:resolved_request_id) { '8a48e8db6d7682c3016d88dc21650024' }
  let(:va_request_id) { '8a48e8db6d70a38a016d72b354240002' }
  let(:cc_request_id) { '8a48912a6d02b0fc016d20b4ccb9001a' }
  let(:va_request_data) do
    data.find { |d| d.appointment_request_id == va_request_id }
  end
  let(:cc_request_data) do
    data.find { |d| d.appointment_request_id == cc_request_id }
  end
  let(:adapted_va_appt_request) do
    va_appointment_requests.find { |request| request.id == va_request_id }
  end
  let(:adapted_cc_appt_request) do
    cc_appointment_requests.find { |request| request.id == cc_request_id }
  end

  describe '#parse' do
    it 'returns lists of va and cc appointment requests' do
      expect(adapted_appointment_requests).to eq([[adapted_va_appt_request], [adapted_cc_appt_request]])
    end
  end

  describe 'is_pending' do
    it 'is always true' do
      is_pending = all_appointment_requests.map(&:is_pending).uniq
      expect(is_pending).to eq([true])
    end
  end

  describe 'unused fields' do
    it 'returns them as nils' do
      comment = all_appointment_requests.map(&:comment).uniq
      sta6aid = all_appointment_requests.map(&:sta6aid).uniq
      minutes_duration = all_appointment_requests.map(&:minutes_duration).uniq
      vetext_id = all_appointment_requests.map(&:vetext_id).uniq
      is_covid_vaccine = all_appointment_requests.map(&:is_covid_vaccine).uniq

      expect([comment, sta6aid, minutes_duration, vetext_id, is_covid_vaccine]).to all(eq([nil]))
    end
  end

  describe 'cancel_id' do
    it 'is appointment id' do
      ids = all_appointment_requests.map(&:id)
      cancel_ids = all_appointment_requests.map(&:cancel_id)
      expect(ids).to eq(cancel_ids)
    end
  end

  describe 'phone_only' do
    it 'is true when visit type is "Phone Call"' do
      va_request_data.visit_type = 'Phone Call'
      va_results, = subject.parse([va_request_data])
      expect(va_results.first.phone_only).to eq(true)
    end

    it 'is false for all other visit types' do
      expect(adapted_va_appt_request[:phone_only]).to eq(false)
      expect(adapted_cc_appt_request[:phone_only]).to eq(false)
    end
  end

  describe 'proposed_times' do
    it 'returns an array of date/time pairs in the order of the option dates/time in the source data' do
      expect(adapted_va_appt_request.proposed_times).to eq(
        [{ date: '10/01/2020', time: 'PM' }, { date: '11/03/2020', time: 'AM' },
         { date: '11/02/2020', time: 'AM' }]
      )
      expect(adapted_cc_appt_request.proposed_times).to eq(
        [{ date: '10/01/2020', time: 'PM' }, { date: '10/02/2020', time: 'PM' },
         { date: nil, time: nil }]
      )
    end
  end

  describe 'time_zone' do
    it 'is based on facility zip code' do
      time_zones = all_appointment_requests.map(&:time_zone).uniq
      expect(time_zones).to eq(['America/Denver'])
    end
  end

  describe 'start_date_local' do
    let(:test_time) { Time.zone.parse('2020-11-01T10:30:00Z') }

    it 'uses the time zone' do
      expect(adapted_va_appt_request.start_date_local.time_zone.name).to end_with('America/Denver')
      expect(adapted_cc_appt_request.start_date_local.time_zone.name).to end_with('America/Denver')
    end

    it 'converts AM to 8AM and PM to 12PM' do
      Timecop.freeze(test_time) do
        expect(adapted_va_appt_request.start_date_local.utc.hour).to eq(8)
        expect(adapted_cc_appt_request.start_date_local.utc.hour).to eq(12)
      end
    end

    context 'when all proposed dates are past' do
      it 'is based on the chronologically first proposed date' do
        Timecop.freeze(test_time) do
          first_time_in_past = '2020-10-01 06:00:00 -0600'
          expect(adapted_cc_appt_request.start_date_local.to_s).to eq(first_time_in_past)
        end
      end
    end

    context 'when any proposed date is in the future' do
      it 'is based on the chronologically first proposed date in the future' do
        Timecop.freeze(test_time) do
          first_appointment_in_future = '2020-11-02 01:00:00 -0700'
          expect(adapted_va_appt_request.start_date_local.to_s).to eq(first_appointment_in_future)
        end
      end
    end
  end

  describe 'start_date_utc' do
    it 'is start_date_local in utc' do
      expect(adapted_va_appt_request.start_date_local.utc).to eq(adapted_va_appt_request.start_date_utc)
    end
  end

  describe 'status' do
    it 'is SUBMITTED for submitted requests' do
      expect(adapted_va_appt_request.status).to eq('SUBMITTED')
    end

    it 'is CANCELLED for cancelled requests' do
      expect(adapted_cc_appt_request.status).to eq('CANCELLED')
    end

    it 'is skipped for any other request type' do
      booked_request = data.find { |d| d.appointment_request_id == booked_request_id }
      resolved_request = data.find { |d| d.appointment_request_id == resolved_request_id }

      # verifying test setup
      expect(booked_request.status).to eq('Booked')
      expect(resolved_request.status).to eq('Resolved')

      adapted_booked_request = all_appointment_requests.find { |r| r.id == booked_request_id }
      adapted_resolved_request = all_appointment_requests.find { |r| r.id == resolved_request_id }

      expect(adapted_booked_request).to be_nil
      expect(adapted_resolved_request).to be_nil
    end
  end

  describe 'status_detail' do
    context 'when status is not cancelled' do
      it 'is nil' do
        expect(adapted_va_appt_request.status_detail).to be_nil
      end
    end

    context 'when detail code is DETCODE22 or DETCODE8' do
      it 'is CANCELLED BY PATIENT' do
        cc_request_data[:appointment_request_detail_code][0][:detail_code][:code] = 'DETCODE22'
        _, results = subject.parse([cc_request_data])
        expect(results.first.status_detail).to eq('CANCELLED BY PATIENT')
        cc_request_data[:appointment_request_detail_code][0][:detail_code][:code] = 'DETCODE8'
        _, results = subject.parse([cc_request_data])
        expect(results.first.status_detail).to eq('CANCELLED BY PATIENT')
      end
    end

    context 'when detail code is DETCODE19' do
      it 'is CANCELLED BY CLINIC' do
        # this request detail code is DETCODE19
        expect(adapted_cc_appt_request.status_detail).to eq('CANCELLED BY CLINIC')
      end
    end

    context 'when detail code is DETCODE24' do
      it 'is CANCELLED - OTHER' do
        cc_request_data[:appointment_request_detail_code][0][:detail_code][:code] = 'DETCODE24'
        _, results = subject.parse([cc_request_data])
        expect(results.first.status_detail).to eq('CANCELLED - OTHER')
      end
    end

    context 'when detail code is anything else' do
      it 'is CANCELLED - OTHER and logs error' do
        cc_request_data[:appointment_request_detail_code][0][:detail_code][:code] = 'DETCODE9000'

        _, results = subject.parse([cc_request_data])
        expect(results.first.status_detail).to eq('CANCELLED - OTHER')
      end
    end
  end

  context 'VA appointment requests' do
    describe 'appointment_type' do
      it 'is VA for office visits' do
        expect(adapted_va_appt_request.appointment_type).to eq('VA')
      end

      it 'is VA for phone call visits' do
        va_request_data.visit_type = 'Phone Call'
        va_results, = subject.parse([va_request_data])
        expect(va_results.first.appointment_type).to eq('VA')
      end

      it 'is VA for express care visits' do
        va_request_data.visit_type = 'Express Care'
        va_results, = subject.parse([va_request_data])
        expect(va_results.first.appointment_type).to eq('VA')
      end

      it 'is VA_VIDEO_CONNECT_HOME for video conference visits' do
        va_request_data.visit_type = 'Video Conference'
        va_results, = subject.parse([va_request_data])
        expect(va_results.first.appointment_type).to eq('VA_VIDEO_CONNECT_HOME')
      end

      it 'is VA and logs to sentry for any other visit type' do
        va_request_data.visit_type = 'Unexpected type'
        va_results, = subject.parse([va_request_data])
        expect(va_results.first.appointment_type).to eq('VA')
      end
    end

    describe 'healthcare_provider' do
      it 'is nil' do
        expect(adapted_va_appt_request.healthcare_provider).to be_nil
      end
    end

    describe 'healthcare_service' do
      it 'is nil' do
        expect(adapted_va_appt_request.healthcare_service).to be_nil
      end
    end

    describe 'facility_id' do
      it 'is set to the facility code' do
        expect(adapted_va_appt_request.facility_id).to eq('442')
      end
    end

    describe 'location' do
      it 'sets facility id and name but leaves everything else nil' do
        expected_location = {
          id: '442',
          name: 'CHEYENNE VAMC',
          address: { street: nil, city: nil, state: nil, zip_code: nil },
          lat: nil,
          long: nil,
          phone: { area_code: nil, number: nil, extension: nil },
          url: nil,
          code: nil
        }
        expect(adapted_va_appt_request.location.to_h).to eq(expected_location)
      end
    end
  end

  context 'CC appointment requests' do
    describe 'appointment_type' do
      it 'is COMMUNITY_CARE for office visits' do
        expect(adapted_cc_appt_request.appointment_type).to eq('COMMUNITY_CARE')
      end

      it 'is COMMUNITY_CARE for phone call visits' do
        cc_request_data.visit_type = 'Phone Call'
        _, cc_results = subject.parse([cc_request_data])
        expect(cc_results.first.appointment_type).to eq('COMMUNITY_CARE')
      end

      it 'is COMMUNITY_CARE and logs for express care visits' do
        cc_request_data.visit_type = 'Express Care'
        _, cc_results = subject.parse([cc_request_data])
        expect(cc_results.first.appointment_type).to eq('COMMUNITY_CARE')
      end

      it 'is COMMUNITY_CARE and logs for video conference visits' do
        cc_request_data.visit_type = 'Video Conference'
        _, cc_results = subject.parse([cc_request_data])
        expect(cc_results.first.appointment_type).to eq('COMMUNITY_CARE')
      end

      it 'is COMMUNITY_CARE and logs to sentry for any other visit type' do
        cc_request_data.visit_type = 'Unexpected type'
        _, cc_results = subject.parse([cc_request_data])
        expect(cc_results.first.appointment_type).to eq('COMMUNITY_CARE')
      end
    end

    describe 'healthcare_provider' do
      it "is the healthcare provider's first and last name" do
        expect(adapted_cc_appt_request.healthcare_provider).to eq('Vilasini Reddy')
      end
    end

    describe 'healthcare_service' do
      it "is the preferred provider's practice name" do
        expect(adapted_cc_appt_request.healthcare_service).to eq('Test clinic 2')
      end
    end

    describe 'facility_id' do
      it 'is nil' do
        expect(adapted_cc_appt_request.facility_id).to be_nil
      end
    end

    describe 'location' do
      it 'sets name and address' do
        expected_location = {
          id: nil,
          name: 'Test clinic 2',
          address: { street: '123 Sesame St.', city: 'Cheyenne', state: 'VA', zip_code: '20171' },
          lat: nil,
          long: nil,
          phone: nil,
          url: nil,
          code: nil
        }
        expect(adapted_cc_appt_request.location.to_h).to eq(expected_location)
      end
    end

    describe 'error handling' do
      it 'will bubble up any errors encountered' do
        allow_any_instance_of(Mobile::V0::Templates::CommunityCareAppointment)
          .to receive(:appointment).and_raise(StandardError)
        expect { adapted_appointment_requests }.to raise_error(StandardError)
      end
    end
  end
end
