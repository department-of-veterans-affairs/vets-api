# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::MobileFacilityService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#configuration' do
    context 'with a facility id' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_200',
                         match_requests_on: %i[method uri]) do
          response = subject.get_scheduling_configurations(489, false)
          expect(response[:data].size).to eq(1)
        end
      end
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
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200',
                         match_requests_on: %i[method uri]) do
          params = {
            ids: %w[688]
          }
          response = subject.get_facilities(params)
          expect(response[:data].size).to eq(1)
        end
      end
    end

    context 'with a facility id and children true' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_with_children_200',
                         match_requests_on: %i[method uri]) do
          params = {
            ids: %w[688],
            children: true
          }
          response = subject.get_facilities(params)
          expect(response[:data].size).to eq(8)
        end
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility/get_facilities_400',
                         match_requests_on: %i[method uri]) do
          expect { subject.get_facilities({}) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility/get_facilities_500',
                         match_requests_on: %i[method uri]) do
          params = {
            ids: %w[688]
          }
          expect { subject.get_facilities(params) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
