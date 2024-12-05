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
end
