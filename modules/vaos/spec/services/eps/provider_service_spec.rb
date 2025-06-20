# frozen_string_literal: true

require 'rails_helper'

describe Eps::ProviderService do
  let(:service) { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }
  let(:config) { instance_double(Eps::Configuration) }
  let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }

  before do
    allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false)
    allow(service).to receive_messages(config:)
    allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:debug)
    allow(Rails.logger).to receive(:public_send)
  end

  describe '#get_provider_service' do
    let(:provider_id) { 123 }

    context 'when the request is successful' do
      let(:response) do
        double('Response', status: 200, body: { id: provider_id, name: 'Provider 1' },
                           response_headers: { 'Content-Type' => 'application/json' })
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
                                                ] },
                           response_headers: { 'Content-Type' => 'application/json' })
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
                                        },
                           response_headers: { 'Content-Type' => 'application/json' })
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
                                              ] },
                         response_headers: { 'Content-Type' => 'application/json' })
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
        response = double('Response', status: 200, body: valid_response.body,
                                      response_headers: { 'Content-Type' => 'application/json' })

        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:get, "/#{config.base_path}/provider-services/#{provider_id}/slots", { nextToken: next_token }, headers)
          .and_return(response)

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
    let(:npi) { '7894563210' }
    let(:specialty) { 'Cardiology' }
    let(:address) do
      {
        street1: '1105 Palmetto Ave',
        city: 'Melbourne',
        state: 'FL',
        zip: '32901'
      }
    end

    context 'when the request is successful' do
      context 'when provider specialty does not match' do
        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: '53mL4LAZ',
                specialties: [{ name: 'Dermatology' }],
                location: {
                  address: '1105 Palmetto Ave, Melbourne, FL, 32901'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
        end

        it 'returns nil' do
          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_nil
        end
      end

      context 'when the response contains no providers' do
        let(:response_body) do
          {
            count: 0,
            provider_services: []
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
        end

        it 'returns nil' do
          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_nil
        end
      end

      context 'when provider has blank specialty' do
        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: '53mL4LAZ',
                specialties: [],
                location: {
                  address: '1105 Palmetto Ave, Melbourne, FL, 32901'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
        end

        it 'returns nil' do
          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_nil
        end
      end

      # New comprehensive tests for specialty and address matching
      context 'when both specialty and address match perfectly' do
        let(:matching_address) do
          {
            street1: '1601 NEEDMORE RD ; STE 1 & 2',
            city: 'DAYTON',
            state: 'Ohio',
            zip: '45414'
          }
        end

        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
        end

        it 'returns the matching provider' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('provider123')
        end
      end

      context 'when specialty matches but address does not' do
        let(:non_matching_address) do
          {
            street1: '123 Different Street',
            city: 'COLUMBUS',
            state: 'Ohio',
            zip: '43201'
          }
        end

        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:warn)
        end

        it 'returns nil and logs warning' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: non_matching_address)
          expect(result).to be_nil
          expect(Rails.logger).to have_received(:warn).with(
            /No address match found among 1 provider\(s\) for NPI #{npi}/
          )
        end
      end

      context 'when specialty matching is case-insensitive' do
        let(:matching_address) do
          {
            street1: '1601 NEEDMORE RD ; STE 1 & 2',
            city: 'DAYTON',
            state: 'Ohio',
            zip: '45414'
          }
        end

        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'CARDIOLOGY' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
        end

        it 'matches specialty regardless of case' do
          result = service.search_provider_services(npi:, specialty: 'cardiology', address: matching_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('provider123')
        end
      end

      context 'when address has zip+4 vs 5-digit zip' do
        let(:zip_5_digit_address) do
          {
            street1: '1601 NEEDMORE RD ; STE 1 & 2',
            city: 'DAYTON',
            state: 'Ohio',
            zip: '45414'
          }
        end

        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
        end

        it 'matches 5-digit zip against zip+4' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: zip_5_digit_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('provider123')
        end
      end

      context 'when zip code does not match' do
        let(:different_zip_address) do
          {
            street1: '1601 NEEDMORE RD ; STE 1 & 2',
            city: 'DAYTON',
            state: 'Ohio',
            zip: '43201'
          }
        end

        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:warn)
        end

        it 'returns nil' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: different_zip_address)
          expect(result).to be_nil
        end
      end

      context 'when street address does not match' do
        let(:different_street_address) do
          {
            street1: '999 Different Street',
            city: 'DAYTON',
            state: 'Ohio',
            zip: '45414'
          }
        end

        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:warn)
        end

        it 'returns nil and logs partial match warning' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: different_street_address)
          expect(result).to be_nil
          expect(Rails.logger).to have_received(:warn).with(
            /Provider address partial match.*Street: false.*Zip: true/
          )
        end
      end

      context 'when multiple providers match specialty' do
        let(:matching_address) do
          {
            street1: '1601 NEEDMORE RD ; STE 1 & 2',
            city: 'DAYTON',
            state: 'Ohio',
            zip: '45414'
          }
        end

        let(:response_body) do
          {
            count: 2,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              },
              {
                id: 'provider456',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '2200 Oak Street, COLUMBUS, OH 43201-1234'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:warn)
        end

        it 'returns the provider with matching address' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('provider123')
        end
      end

      context 'when multiple providers match specialty but none match address' do
        let(:non_matching_address) do
          {
            street1: '999 Nowhere Street',
            city: 'TOLEDO',
            state: 'Ohio',
            zip: '43604'
          }
        end

        let(:response_body) do
          {
            count: 2,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              },
              {
                id: 'provider456',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '2200 Oak Street, COLUMBUS, OH 43201-1234'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:warn)
        end

        it 'returns nil and logs warning' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: non_matching_address)
          expect(result).to be_nil
          expect(Rails.logger).to have_received(:warn).with(
            /No address match found among 2 provider\(s\) for NPI #{npi}/
          )
        end
      end

      context 'when provider has missing address components' do
        let(:matching_address) do
          {
            street1: '1601 NEEDMORE RD ; STE 1 & 2',
            city: 'DAYTON',
            state: 'Ohio',
            zip: '45414'
          }
        end

        let(:response_body) do
          {
            count: 1,
            provider_services: [
              {
                id: 'provider123',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: 'Incomplete Address'
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:warn)
        end

        it 'returns nil when provider address cannot be parsed' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
          expect(result).to be_nil
        end
      end

      # Test cases for zip code extraction with street addresses containing 5-digit numbers
      context 'when handling zip code extraction with various address formats' do
        let(:response_body) do
          {
            count: 3,
            provider_services: [
              {
                id: 'provider1',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848, US' # 4-digit street, zip+4
                }
              },
              {
                id: 'provider2',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '16011 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848' # 5-digit street, zip+4
                }
              },
              {
                id: 'provider3',
                specialties: [{ name: 'Cardiology' }],
                location: {
                  address: '16011 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414, US' # 5-digit street, 5-digit zip
                }
              }
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
        end

        context 'when matching against 4-digit street address with zip+4' do
          let(:matching_address) do
            {
              street1: '1601 NEEDMORE RD ; STE 1 & 2',
              city: 'DAYTON',
              state: 'Ohio',
              zip: '45414'
            }
          end

          it 'correctly extracts zip code ignoring street number' do
            result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
            expect(result).to be_a(OpenStruct)
            expect(result.id).to eq('provider1')
          end
        end

        context 'when matching against 5-digit street address with zip+4' do
          let(:matching_address) do
            {
              street1: '16011 NEEDMORE RD ; STE 1 & 2',
              city: 'DAYTON',
              state: 'Ohio',
              zip: '45414'
            }
          end

          it 'correctly extracts last zip code, not street number' do
            result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
            expect(result).to be_a(OpenStruct)
            expect(result.id).to eq('provider2')
          end
        end

        context 'when matching against 5-digit street address with 5-digit zip' do
          let(:matching_address) do
            {
              street1: '16011 NEEDMORE RD ; STE 1 & 2',
              city: 'DAYTON',
              state: 'Ohio',
              zip: '45414'
            }
          end

          it 'correctly extracts last zip code, not street number' do
            result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
            expect(result).to be_a(OpenStruct)
            # Both provider2 and provider3 have same street and same zip, so either could match
            expect(result.id).to be_in(%w[provider2 provider3])
          end
        end

        context 'when street number matches but zip does not' do
          let(:non_matching_address) do
            {
              street1: '16011 NEEDMORE RD ; STE 1 & 2',
              city: 'DAYTON',
              state: 'Ohio',
              zip: '43201' # Different zip
            }
          end

          before do
            allow(Rails.logger).to receive(:warn)
          end

          it 'does not match against street number' do
            result = service.search_provider_services(npi:, specialty: 'Cardiology', address: non_matching_address)
            expect(result).to be_nil
          end
        end

        context 'when street address contains zip+4 format number' do
          let(:response_body) do
            {
              count: 1,
              provider_services: [
                {
                  id: 'provider_extreme',
                  specialties: [{ name: 'Cardiology' }],
                  location: {
                    # Extreme case: street address has 45414-3333 format, but actual zip is 12345
                    address: '45414-3333 FAKE STREET, COLUMBUS, OH 12345-6789, US'
                  }
                }
              ]
            }
          end

          let(:matching_address) do
            {
              street1: '45414-3333 FAKE STREET',
              city: 'COLUMBUS',
              state: 'Ohio',
              zip: '12345' # Should match the LAST zip code (12345), not the street number (45414)
            }
          end

          let(:response) do
            double('Response', status: 200, body: response_body,
                               response_headers: { 'Content-Type' => 'application/json' })
          end

          before do
            allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          end

          it 'extracts actual zip code, not zip-like street number' do
            result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
            expect(result).to be_a(OpenStruct)
            expect(result.id).to eq('provider_extreme')
          end
        end
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
        expect { service.search_provider_services(npi:, specialty:, address:) }
          .to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end
  end
end
