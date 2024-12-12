# frozen_string_literal: true

require 'rails_helper'

describe Eps::ProviderService do
  let(:service) { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }
  let(:config) { instance_double(Eps::Configuration) }
  let(:headers) { { 'Authorization' => 'Bearer token123' } }

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
end
