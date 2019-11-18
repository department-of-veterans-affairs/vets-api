# frozen_string_literal: true

require 'rails_helper'

describe VAOS::SystemsService do
  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_systems' do
    context 'with 10 system identifiers' do
      it 'returns an array of size 10' do
        VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method uri]) do
          response = subject.get_systems(user)
          expect(response.size).to eq(10)
        end
      end

      it 'increments metrics total' do
        VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[method uri]) do
          expect { subject.get_systems(user) }.to trigger_statsd_increment(
            'api.vaos.get_systems.total', times: 1, value: 1
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_systems_500', match_requests_on: %i[method uri]) do
          expect { subject.get_systems(user) }.to trigger_statsd_increment(
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
          expect { subject.get_systems(user) }.to trigger_statsd_increment(
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
          response = subject.get_facilities(user, '688')
          expect(response.size).to eq(141)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_facilities_500', match_requests_on: %i[method uri]) do
          expect { subject.get_facilities(user, '688') }.to raise_error(
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
          response = subject.get_facility_clinics(user, '983', '323', '983')
          expect(response.size).to eq(4)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_facility_clinics_500', match_requests_on: %i[method uri]) do
          expect { subject.get_facility_clinics(user, '984', '323', '984GA') }.to raise_error(
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
          response = subject.get_cancel_reasons(user, '984')
          expect(response.size).to eq(6)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/systems/get_cancel_reasons_500', match_requests_on: %i[method uri]) do
          expect { subject.get_cancel_reasons(user, '984') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
