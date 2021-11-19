# frozen_string_literal: true

require 'rails_helper'

describe VAOS::SystemsService do
  subject { VAOS::SystemsService.new(user) }

  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_systems' do
    context 'with 10 identifiers and 4 systems' do
      it 'returns an array of size 4' do
        VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method uri]) do
          response = subject.get_systems
          expect(response.size).to eq(4)
        end
      end

      it 'increments metrics total' do
        VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method uri]) do
          expect { subject.get_systems }.to trigger_statsd_increment(
            'api.vaos.get_systems.total', times: 1, value: 1
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_systems_500', match_requests_on: %i[method uri]) do
          expect { subject.get_systems }.to trigger_statsd_increment(
            'api.vaos.get_systems.total', times: 1, value: 1
          ).and trigger_statsd_increment(
            'api.vaos.get_systems.fail', times: 1, value: 1
          ).and raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'when the upstream server returns a 403' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_systems_403', match_requests_on: %i[method uri]) do
          expect { subject.get_systems }.to trigger_statsd_increment(
            'api.vaos.get_systems.fail', times: 1, value: 1
          ).and raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end

  describe '#get_facilities' do
    context 'with 141 facilities' do
      it 'returns an array of size 141' do
        VCR.use_cassette('vaos/systems/get_facilities', match_requests_on: %i[method uri]) do
          response = subject.get_facilities('688')
          expect(response.size).to eq(141)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_facilities_500', match_requests_on: %i[method uri]) do
          expect { subject.get_facilities('688') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_facility_clinics' do
    context 'with 1 clinic' do
      it 'returns an array of size 1' do
        VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
          response = subject.get_facility_clinics('983', '323', '983')
          expect(response.size).to eq(4)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_facility_clinics_500', match_requests_on: %i[method uri]) do
          expect { subject.get_facility_clinics('984GA', '323', '984') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_cancel_reasons' do
    context 'with a 200 response' do
      it 'returns an array of size 6' do
        VCR.use_cassette('vaos/systems/get_cancel_reasons', match_requests_on: %i[method uri]) do
          response = subject.get_cancel_reasons('984')
          expect(response.size).to eq(6)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_cancel_reasons_500', match_requests_on: %i[method uri]) do
          expect { subject.get_cancel_reasons('984') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_available_appointments' do
    let(:facility_id) { '688' }
    let(:start_date) { DateTime.new(2019, 11, 22) }
    let(:end_date) { DateTime.new(2020, 2, 19) }
    let(:clinic_ids) { ['2276'] }

    context 'with a 200 response' do
      it 'lists available times by facility with coerced dates' do
        VCR.use_cassette('vaos/systems/get_facility_available_appointments', match_requests_on: %i[method uri]) do
          response = subject.get_facility_available_appointments(facility_id, start_date, end_date, clinic_ids)
          clinic = response.first
          first_available_time = clinic.appointment_time_slot.first
          expect(clinic.clinic_id).to eq(clinic_ids.first)
          expect(first_available_time.start_date_time.to_s).to eq('2019-12-02T13:30:00+00:00')
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_facility_appointments', match_requests_on: %i[method uri]) do
          expect { subject.get_cancel_reasons('984') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_system_facilities' do
    context 'with a 200 response' do
      it 'returns the six facilities for the system with id of 688' do
        VCR.use_cassette('vaos/systems/get_system_facilities', match_requests_on: %i[method uri]) do
          response = subject.get_system_facilities('688', '688', '323')
          expect(response.size).to eq(6)
        end
      end

      it 'flattens the facility data' do
        VCR.use_cassette('vaos/systems/get_system_facilities', match_requests_on: %i[method uri]) do
          response = subject.get_system_facilities('688', '688', '323')
          facility = response.first.to_h
          expect(facility).to eq(
            request_supported: true,
            direct_scheduling_supported: true,
            express_times: nil,
            institution_timezone: 'America/New_York',
            institution_code: '688',
            name: 'Washington VA Medical Center',
            city: 'Washington',
            state_abbrev: 'DC',
            authoritative_name: 'Washington VA Medical Center',
            root_station_code: '688',
            admin_parent: true, parent_station_code: '688'
          )
        end
      end
    end

    context 'with express care' do
      it 'includes express care data' do
        VCR.use_cassette('vaos/systems/get_system_facilities_express_care', match_requests_on: %i[method uri]) do
          response = subject.get_system_facilities('983', '983', 'CR1')
          expect(response.pluck(:express_times)).to eq(
            [
              {
                start: '09:17',
                end: '16:45',
                timezone: 'MDT',
                offset_utc: '-06:00'
              },
              {
                start: '12:04',
                end: '14:04',
                timezone: 'MDT',
                offset_utc: '-06:00'
              },
              {
                start: '12:35',
                end: '12:45',
                timezone: 'MDT',
                offset_utc: '-06:00'
              },
              {
                start: '08:33',
                end: '23:33',
                timezone: 'MDT',
                offset_utc: '-06:00'
              }
            ]
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_system_facilities_500', match_requests_on: %i[method uri]) do
          expect { subject.get_system_facilities('688', '688', '323') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_facility_limits' do
    context 'with a 200 response' do
      it 'returns the number of requests and limits for a facility' do
        VCR.use_cassette('vaos/systems/get_facility_limits', match_requests_on: %i[method uri]) do
          response = subject.get_facility_limits('688', '323')
          expect(response.number_of_requests).to eq(0)
          expect(response.request_limit).to eq(1)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_facility_limits_500', match_requests_on: %i[method uri]) do
          expect { subject.get_facility_limits('688', '323') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_facilities_limits with multiple institution_codes' do
    let(:user) { build(:user, :vaos) }

    context 'with a 200 response' do
      it 'returns a number of requests and limits for multiple facilities' do
        VCR.use_cassette('vaos/systems/get_facilities_limits_for_multiple', match_requests_on: %i[method uri]) do
          response = subject.get_facilities_limits(%w[688 442], '323')
          expect(response.size).to eq(2)
        end
      end
    end

    context 'with a 500 response' do
      it 'returns a number of requests and limits for multiple facilities' do
        VCR.use_cassette('vaos/systems/get_facilities_limits_for_multiple_500', match_requests_on: %i[method uri]) do
          expect { subject.get_facility_limits(%w[688 442], '323') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_system_pact' do
    context 'with a 200 response' do
      it 'returns pact info' do
        VCR.use_cassette('vaos/systems/get_system_pact', match_requests_on: %i[method uri]) do
          response = subject.get_system_pact('688')
          expect(response.size).to eq(6)
          expect(response.first.to_h).to eq(
            facility_id: '688',
            possible_primary: 'Y',
            provider_position: 'GREEN-FOUR PHYSICIAN',
            provider_sid: '3780868',
            staff_name: 'VASSALL,NATALIE M',
            team_name: 'GREEN-FOUR',
            team_purpose: 'PRIMARY CARE',
            team_sid: '1400018881',
            title: 'PHYSICIAN-ATTENDING'
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_system_pact_500', match_requests_on: %i[method uri]) do
          expect { subject.get_system_pact('688') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_facility_visits' do
    context 'with a 200 response for direct visits that is false' do
      it 'returns facility information showing no visits' do
        VCR.use_cassette('vaos/systems/get_facility_visits', match_requests_on: %i[method uri]) do
          response = subject.get_facility_visits('688', '688', '323', 'direct')
          expect(response.has_visited_in_past_months).to be_falsey
          expect(response.duration_in_months).to eq(0)
        end
      end
    end

    context 'with a 200 response for request visits that is true' do
      it 'returns facility information showing a past visit' do
        VCR.use_cassette('vaos/systems/get_facility_visits_request', match_requests_on: %i[method uri]) do
          response = subject.get_facility_visits('688', '688', '323', 'request')
          expect(response.has_visited_in_past_months).to be_truthy
          expect(response.duration_in_months).to eq(2)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_system_pact_500', match_requests_on: %i[method uri]) do
          expect { subject.get_system_pact('688') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_facility_visits_500', match_requests_on: %i[method uri]) do
          expect { subject.get_facility_visits('688', '688', '323', 'direct') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_clinic_institutions' do
    context 'with a 200 response for a set of clinic ids' do
      let(:system_id) { 442 }
      let(:clinic_ids) { [16, 90, 110, 192, 193] }

      it 'returns only those clinics parsed correctly', :aggregate_failures do
        VCR.use_cassette('vaos/systems/get_institutions', match_requests_on: %i[method uri]) do
          response = subject.get_clinic_institutions(system_id, clinic_ids)
          expect(response.map { |c| c[:location_ien].to_i }).to eq(clinic_ids)
          expect(response.last.to_h).to eq(
            institution_code: '442',
            institution_ien: '442',
            institution_name: 'CHEYENNE VA MEDICAL',
            institution_sid: 561_596,
            location_ien: '193'
          )
        end
      end
    end

    context 'with a 200 response for a set of clinic ids' do
      let(:system_id) { 442 }
      let(:clinic_ids) { 16 }

      it 'returns only those clinics parsed correctly', :aggregate_failures do
        VCR.use_cassette('vaos/systems/get_institutions_single', match_requests_on: %i[method uri]) do
          response = subject.get_clinic_institutions(system_id, clinic_ids)
          expect(response.map { |c| c[:location_ien].to_i }).to eq([*clinic_ids])
          expect(response.first.to_h).to eq(
            institution_code: '442',
            institution_ien: '442',
            institution_name: 'CHEYENNE VA MEDICAL',
            institution_sid: 561_596,
            location_ien: '16'
          )
        end
      end
    end
  end

  describe '#get_request_eligibility_criteria' do
    context 'with a site_codes param array' do
      it 'returns an array', :aggregate_failures do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_site_codes',
                         match_requests_on: %i[method uri]) do
          response = subject.get_request_eligibility_criteria(site_codes: %w[442 534])
          expect(response.size).to eq(2)
          first_result = response.first
          expect(first_result.id).to eq('442')
          expect(first_result.request_settings.first).to eq(
            {
              id: '203',
              type_of_care: 'Audiology',
              patient_history_duration: 0,
              stop_codes: [{ primary: '203' }],
              submitted_request_limit: 2,
              enterprise_submitted_request_limit: 2
            }
          )
        end
      end
    end

    context 'with a parent_sites param array' do
      it 'returns an array', :aggregate_failures do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_parent_sites',
                         match_requests_on: %i[method uri]) do
          response = subject.get_request_eligibility_criteria(parent_sites: %w[983 984])
          expect(response.size).to eq(5)
          first_result = response.first
          expect(first_result.id).to eq('984')
          expect(first_result.request_settings.first).to eq(
            { id: '123',
              type_of_care: 'Food and Nutrition',
              patient_history_required: 'No',
              patient_history_duration: 0,
              stop_codes: [{ primary: '123' }, { primary: '124' }],
              submitted_request_limit: 1,
              enterprise_submitted_request_limit: 2 }
          )
        end
      end
    end
  end

  describe '#get_request_eligibility_criteria_by_id' do
    context 'with a single id' do
      it 'returns the criteria for a single facility', :aggregate_failures do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_id',
                         match_requests_on: %i[method uri]) do
          response = subject.get_request_eligibility_criteria(site_codes: '688')
          expect(response.first.to_h).to eq(
            { links: [{ title: 'request-eligibility-criteria',
                        href: '/facilities/v1/request-eligibility-criteria',
                        object_type: 'AtomLink' }],
              id: '688',
              created_date: '2020-05-01T16:45:26Z',
              last_modified_date: '2018-11-01T16:54:41Z',
              created_by: 'Shepard, Sandy',
              modified_by: 'BENTT,DEYNE R',
              request_settings: [{ id: '203',
                                   type_of_care: 'Audiology',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '203' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '323',
                                   type_of_care: 'Primary Care',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '322' }, { primary: '323' }, { primary: '350' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 1 },
                                 { id: '408',
                                   type_of_care: 'Optometry',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '408' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '502',
                                   type_of_care: 'Outpatient Mental Health',
                                   patient_history_required: 'No',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '502' }],
                                   submitted_request_limit: 1,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '123',
                                   type_of_care: 'Food and Nutrition',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '123' }, { primary: '124' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '372',
                                   type_of_care: 'MOVE! program',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '372' }, { primary: '373' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '349',
                                   type_of_care: 'CPAP Clinic',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '349', secondary: '116' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '160',
                                   type_of_care: 'Clinical Pharmacy-Primary Care',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '160', secondary: '323' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '143',
                                   type_of_care: 'Sleep Medicine – Home Sleep Testing',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '143', secondary: '189' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '211',
                                   type_of_care: 'Amputation Services',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '211' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '125',
                                   type_of_care: 'Social Work',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '125', secondary: '323' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 },
                                 { id: '407',
                                   type_of_care: 'Ophthalmology',
                                   patient_history_duration: 0,
                                   stop_codes: [{ primary: '407' }],
                                   submitted_request_limit: 0,
                                   enterprise_submitted_request_limit: 2 }],
              custom_request_settings: [{ id: 'CR1',
                                          type_of_care: 'Express Care',
                                          submitted_request_limit: 0,
                                          enterprise_submitted_request_limit: 2,
                                          supported: false,
                                          scheduling_days: [{ day: 'MONDAY', can_schedule: false },
                                                            { day: 'TUESDAY', can_schedule: false },
                                                            { day: 'WEDNESDAY', can_schedule: false },
                                                            { day: 'THURSDAY', can_schedule: false },
                                                            { day: 'FRIDAY', can_schedule: false },
                                                            { day: 'SATURDAY', can_schedule: false },
                                                            { day: 'SUNDAY', can_schedule: false }] }] }
          )
        end
      end
    end
  end

  describe '#get_direct_booking_elig_crit' do
    context 'with a site_codes param array' do
      it 'returns an array', :aggregate_failures do
        VCR.use_cassette('vaos/systems/get_direct_booking_eligibility_criteria_by_site_codes',
                         match_requests_on: %i[method uri]) do
          response = subject.get_direct_booking_elig_crit(site_codes: %w[442 534])
          expect(response.size).to eq(2)
          first_result = response.first
          second_result = response.second
          expect(first_result.id).to eq('442')
          expect(second_result.id).to eq('534')
        end
      end
    end
  end
end
