# frozen_string_literal: true

require 'rails_helper'

describe Eps::ProviderService do
  let(:service) { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }
  let(:config) { instance_double(Eps::Configuration) }
  let(:headers) { { 'Authorization' => 'Bearer token123' } }

  let(:successful_drive_time_response) do
    double('Response', status: 200, body: {
        'destinations' => {
          '00eff3f3-ecfb-41ff-9ebc-78ed811e17f9' => {
            'distanceInMiles' => '4',
            'driveTimeInSecondsWithTraffic' => '566',
            'driveTimeInSecondsWithoutTraffic' => '493',
            'latitude' => '-74.12870564772521',
            'longitude' => '-151.6240405624497'
          },
          '69cd9203-5e92-47a3-aa03-94b03752872a' => {
            'distanceInMiles' => '9',
            'driveTimeInSecondsWithTraffic' => '1314',
            'driveTimeInSecondsWithoutTraffic' => '1039',
            'latitude' => '-1.7437745123171688',
            'longitude' => '-54.19187859370315'
          }
        },
        'origin' => {
          'latitude' => '4.627174468915552',
          'longitude' => '-88.72187894562788'
        }
      })
  end
  let(:referral_id) { 'test-referral-id' }
  # TODO: make successful_referrals_response test object,
  # once we know what that should look like.

  before do
    allow(config).to receive(:base_path).and_return('api/v1')
    allow(service).to receive_messages(config: config, headers: headers)
  end

  describe '#get_provider_services' do
    context 'when the request is successful' do
      let(:response) do
        double('Response', status: 200, body: { count: 1,
                                                providerServices: [
                                                  { id: '1Awee9b5', name: 'Provider 1' },
                                                  { id: '2Awee9b5', name: 'Provider 2' }
                                                ] })
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
      end

      it 'returns an OpenStruct with the response body' do
        result = service.get_provider_services

        expect(result).to eq(OpenStruct.new(response.body))
      end
    end

    context 'when the request fails' do
      let(:response) { double('Response', status: 500, body: 'Unknown service exception') }
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, response.status, response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'raises an error' do
        expect { service.get_provider_services }.to raise_error(Common::Exceptions::BackendServiceException,
                                                                /VA900/)
      end
    end
  end

  describe '#get_provider_service' do
    let(:provider_id) { 123 }

    context 'when the request is successful' do
      let(:response) do
        double('Response', status: 200, body: { id: provider_id, name: 'Provider 1' })
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
      end

      it 'returns an OpenStruct with the response body' do
        result = service.get_provider_service(provider_id:)

        expect(result).to eq(OpenStruct.new(response.body))
      end
    end

    context 'when the request fails' do
      let(:response) { double('Response', status: 500, body: 'Unknown service exception') }
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, response.status, response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'raises an error' do
        expect do
          service.get_provider_service(provider_id:)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end
  end

  describe '#get_networks' do
    context 'when the request is successful' do
      let(:response) do
        double('Response', status: 200, body: { count: 1,
                                                networks: [
                                                  { id: 'network-5vuTac8v', name: 'Care Navigation' },
                                                  { id: 'network-2Awee9b5', name: 'Take Care Navigation' }
                                                ] })
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
      end

      it 'returns an OpenStruct with the response body' do
        result = service.get_networks

        expect(result).to eq(OpenStruct.new(response.body))
      end
    end

    context 'when the request fails' do
      let(:response) { double('Response', status: 500, body: 'Unknown service exception') }
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, response.status, response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'raises an error' do
        expect { service.get_networks }.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end
  end

  describe 'get_drive_times' do
    context 'when requesting drive times for a logged in user' do
      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(successful_drive_time_response)
      end

      it 'returns the calculated drive times' do
        exp_response = OpenStruct.new(successful_drive_time_response.body)

        expect(service.get_drive_times).to eq(exp_response)
      end
    end

    context 'when the endpoint fails to return appointments' do
      let(:failed_drive_time_response) do
        double('Response', status: 500, body: 'Unknown service exception')
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_drive_time_response.status,
        failed_drive_time_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'throws exception' do
        expect { service.get_drive_times }.to raise_error(Common::Exceptions::BackendServiceException,
                                                           /VA900/)
      end
    end
  end
end
