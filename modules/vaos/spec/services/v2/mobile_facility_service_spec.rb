# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::MobileFacilityService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#configuration' do
    context 'with a single facility id arg' do
      it 'returns a scheduling configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
                         match_requests_on: %i[method uri], tag: :force_utf8) do
          response = subject.get_scheduling_configurations('489')
          expect(response[:data].size).to eq(1)
        end
      end
    end

    context 'with multiple facility ids arg' do
      it 'returns scheduling configurations' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
                         match_requests_on: %i[method uri], tag: :force_utf8) do
          response = subject.get_scheduling_configurations('489,984')
          expect(response[:data].size).to eq(2)
        end
      end
    end

    context 'with multiple facility ids and cc enabled args' do
      it 'returns scheduling configuration'
      # TODO: passing in the cc_enabled argument is currently ignored by the VAOS Service.
      # Once fixed, implement this rspec.
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_500',
                         match_requests_on: %i[method uri]) do
          expect { subject.get_scheduling_configurations(489, false) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#facilities' do
    context 'with a facility id' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_single_id_200',
                         match_requests_on: %i[method uri]) do
          response = subject.get_facilities(ids: '688')
          expect(response[:data].size).to eq(1)
        end
      end
    end

    context 'with multiple facility ids' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200',
                         match_requests_on: %i[method uri]) do
          response = subject.get_facilities(ids: '983,984')
          expect(response[:data].size).to eq(2)
        end
      end
    end

    context 'with a facility id and children true' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_with_children_200',
                         match_requests_on: %i[method uri]) do
          response = subject.get_facilities(children: true, ids: '688')
          expect(response[:data].size).to eq(8)
        end
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_400',
                         match_requests_on: %i[method uri]) do
          expect { subject.get_facilities(ids: 688) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_500',
                         match_requests_on: %i[method uri]) do
          expect { subject.get_facilities(ids: '688') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_facility' do
    context 'with a valid request' do
      it 'returns a facility' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                         match_requests_on: %i[method uri]) do
          response = subject.get_facility('983')
          expect(response[:id]).to eq('983')
          expect(response[:type]).to eq('va_facilities')
          expect(response[:name]).to eq('Cheyenne VA Medical Center')
        end
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_400',
                         match_requests_on: %i[method uri]) do
          expect { subject.get_facility('983') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_500',
                         match_requests_on: %i[method uri]) do
          expect { subject.get_facility('983') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
