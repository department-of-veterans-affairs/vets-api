# frozen_string_literal: true

require 'rails_helper'

describe Eps::ProviderService do
  let(:service) { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }
  let(:config) { instance_double(Eps::Configuration) }
  let(:headers) { { 'Authorization' => 'Bearer token123' } }

  before do
    allow(config).to receive(:base_path).and_return('api/v1')
    allow(service).to receive_messages(config:, headers:)
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
    let(:destinations) do
      {
        'provider-123' => {
          latitude: 40.7128,
          longitude: -74.0060
        }
      }
    end
    let(:origin) do
      {
        latitude: 40.7589,
        longitude: -73.9851
      }
    end

    context 'when the request is successful' do
      let(:response) do
        double('Response', status: 200, body: {
                 'destinations' => {
                   '00eff3f3-ecfb-41ff-9ebc-78ed811e17f9' => {
                     'distanceInMiles' => '4',
                     'driveTimeInSecondsWithTraffic' => '566',
                     'driveTimeInSecondsWithoutTraffic' => '493',
                     'latitude' => '-74.12870564772521',
                     'longitude' => '-151.6240405624497'
                   }
                 },
                 'origin' => {
                   'latitude' => '4.627174468915552',
                   'longitude' => '-88.72187894562788'
                 }
               })
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
      end

      it 'returns the calculated drive times' do
        result = service.get_drive_times(destinations:, origin:)

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
          service.get_drive_times(destinations:, origin:)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end
  end

  describe '#get_provider_slots' do
    let(:provider_id) { '9mN718pH' }
    let(:required_params) do
      {
        appointmentTypeId: 'type123',
        startOnOrAfter: '2024-01-01T00:00:00Z',
        startBefore: '2024-01-02T00:00:00Z'
      }
    end
    let(:valid_response) do
      double('Response', status: 200, body: { count: 1,
                                              slots: [
                                                { id: 'slot1', providerServiceId: '9mN718pH' },
                                                { id: 'slot2', providerServiceId: '9mN718pH' }
                                              ] })
    end

    context 'when provider_id is invalid' do
      it 'raises ArgumentError when provider_id is nil' do
        expect do
          service.get_provider_slots(nil, nextToken: 'token123')
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end

      it 'raises ArgumentError when provider_id is empty' do
        expect do
          service.get_provider_slots('', nextToken: 'token123')
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end

      it 'raises ArgumentError when provider_id is blank' do
        expect do
          service.get_provider_slots('   ', nextToken: 'token123')
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end
    end

    context 'when nextToken is provided' do
      it 'makes request with nextToken parameter' do
        next_token = 'token123'
        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:get, "/#{config.base_path}/provider-services/#{provider_id}/slots", { nextToken: next_token }, headers)
          .and_return(OpenStruct.new(valid_response.body))

        service.get_provider_slots(provider_id, nextToken: next_token)
      end
    end

    context 'when required and additional parameters are provided' do
      it 'makes request with all parameters' do
        params_with_extra = required_params.merge(appointmentId: 'id123')

        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:get, "/#{config.base_path}/provider-services/#{provider_id}/slots", params_with_extra, headers)
          .and_return(valid_response)

        service.get_provider_slots(provider_id, params_with_extra)
      end
    end

    context 'when required parameters are missing' do
      it 'raises ArgumentError when appointmentTypeId is missing' do
        expect do
          service.get_provider_slots(provider_id, required_params.except(:appointmentTypeId))
        end.to raise_error(ArgumentError, /Missing required parameters: appointmentTypeId/)
      end

      it 'raises ArgumentError when startOnOrAfter is missing' do
        expect do
          service.get_provider_slots(provider_id, required_params.except(:startOnOrAfter))
        end.to raise_error(ArgumentError, /Missing required parameters: startOnOrAfter/)
      end

      it 'raises ArgumentError when startBefore is missing' do
        expect do
          service.get_provider_slots(provider_id, required_params.except(:startBefore))
        end.to raise_error(ArgumentError, /Missing required parameters: startBefore/)
      end

      it 'raises ArgumentError when multiple required parameters are missing' do
        expect do
          service.get_provider_slots(provider_id, required_params.except(:startOnOrAfter, :startBefore))
        end.to raise_error(ArgumentError, /Missing required parameters: startOnOrAfter, startBefore/)
      end
    end

    context 'when required parameters are provided and request is successful' do
      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(valid_response)
      end

      it 'returns an OpenStruct with the response body' do
        result = service.get_provider_slots(provider_id, required_params)

        expect(result).to eq(OpenStruct.new(valid_response.body))
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
          service.get_provider_slots(provider_id, required_params)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end
  end

  describe '#search_provider_services' do
    let(:search_params) do
      {
        search_text: 'Acme Medical',
        appointment_id: 'e2487f73-62e7-476b-a8b7-503333572d2a',
        npi: '1245319599',
        network_id: '69cd9203-5e92-47a3-aa03-94b03752872a'
      }
    end

    let(:expected_params) do
      {
        searchText: 'Acme Medical',
        appointmentId: 'e2487f73-62e7-476b-a8b7-503333572d2a',
        npi: '1245319599',
        networkId: '69cd9203-5e92-47a3-aa03-94b03752872a'
      }
    end

    let(:valid_response) do
      double('Response', status: 200, body: {
               count: 1,
               providerServices: [
                 {
                   id: '69cd9203-5e92-47a3-aa03-94b03752872a',
                   name: 'Acme Medical Group',
                   npi: '1245319599'
                 }
               ]
             })
    end

    context 'when the request is successful' do
      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:get, "/#{config.base_path}/provider-services", expected_params, headers)
          .and_return(valid_response)
      end

      it 'returns an OpenStruct with the response body' do
        result = service.search_provider_services(search_params)
        expect(result).to eq(OpenStruct.new(valid_response.body))
      end

      it 'handles optional parameters' do
        optional_params = search_params.merge(
          max_miles_from_near: 25,
          near_location: '90.0,180.0',
          organization_names: ['Alpha Cardiology'],
          specialty_ids: ['207XX0004X'],
          visit_modes: ['in-person'],
          include_inactive: false,
          digital_or_not: 'digital',
          is_self_schedulable: true
        )

        expected_optional_params = expected_params.merge(
          maxMilesFromNear: 25,
          nearLocation: '90.0,180.0',
          organizationNames: ['Alpha Cardiology'],
          specialtyIds: ['207XX0004X'],
          visitModes: ['in-person'],
          includeInactive: false,
          digitalOrNot: 'digital',
          isSelfSchedulable: true
        )

        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:get, "/#{config.base_path}/provider-services", expected_optional_params, headers)
          .and_return(valid_response)

        service.search_provider_services(optional_params)
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
        expect { service.search_provider_services(search_params) }
          .to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end
  end
end
