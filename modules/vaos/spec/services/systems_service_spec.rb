# frozen_string_literal: true

require 'rails_helper'

describe VAOS::SystemsService do
  subject { VAOS::SystemsService.new(user) }

  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_systems' do
    context 'with 10 system identifiers' do
      it 'returns an array of size 10' do
        VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method uri]) do
          response = subject.get_systems
          expect(response.size).to eq(10)
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
          expect { subject.get_facility_clinics('984', '323', '984GA') }.to raise_error(
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
end
