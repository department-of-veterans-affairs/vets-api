# frozen_string_literal: true

require 'rails_helper'

describe VAOS::SystemsService do
  subject { VAOS::SystemsService.new(user) }

  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_system_pact' do
    context 'with a 200 response' do
      it 'returns pact info' do
        VCR.use_cassette('vaos/systems/get_system_pact', match_requests_on: %i[method path query]) do
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
        VCR.use_cassette('vaos/systems/get_system_pact_500', match_requests_on: %i[method path query]) do
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
        VCR.use_cassette('vaos/systems/get_facility_visits', match_requests_on: %i[method path query]) do
          response = subject.get_facility_visits('688', '688', '323', 'direct')
          expect(response.has_visited_in_past_months).to be_falsey
          expect(response.duration_in_months).to eq(0)
        end
      end
    end

    context 'with a 200 response for request visits that is true' do
      it 'returns facility information showing a past visit' do
        VCR.use_cassette('vaos/systems/get_facility_visits_request', match_requests_on: %i[method path query]) do
          response = subject.get_facility_visits('688', '688', '323', 'request')
          expect(response.has_visited_in_past_months).to be_truthy
          expect(response.duration_in_months).to eq(2)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_facility_visits_500', match_requests_on: %i[method path query]) do
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
        VCR.use_cassette('vaos/systems/get_institutions', match_requests_on: %i[method path query]) do
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

    context 'with a 200 response for a single clinic id' do
      let(:system_id) { 442 }
      let(:clinic_ids) { 16 }

      it 'returns the correctly parsed clinic', :aggregate_failures do
        VCR.use_cassette('vaos/systems/get_institutions_single', match_requests_on: %i[method path query]) do
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
                         match_requests_on: %i[method path query]) do
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
                         match_requests_on: %i[method path query]) do
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
                         match_requests_on: %i[method path query]) do
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
                         match_requests_on: %i[method path query]) do
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
