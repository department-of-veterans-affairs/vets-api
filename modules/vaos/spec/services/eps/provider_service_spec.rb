# frozen_string_literal: true

require 'rails_helper'

describe Eps::ProviderService do
  let(:service) { described_class.new(user) }
  let(:user) { double('User', account_uuid: '1234', uuid: 'user-uuid-123', va_treatment_facility_ids: ['123']) }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:debug)
    allow(Rails.logger).to receive(:public_send)
    allow(Rails.logger).to receive(:warn)
    allow(StatsD).to receive(:increment)
    # Bypass token authentication which is tested in another spec
    allow(Settings.vaos.eps).to receive(:mock).and_return(true)
    # Set up RequestStore for controller name logging
    RequestStore.store['controller_name'] = 'VAOS::V2::AppointmentsController'
    # Clear eps_trace_id to ensure test isolation
    RequestStore.store['eps_trace_id'] = nil
    # Mock PersonalInformationLog to avoid database interactions during tests
    allow(PersonalInformationLog).to receive(:create)
  end

  describe '#get_provider_service' do
    let(:provider_id) { 123 }
    let(:config) { instance_double(Eps::Configuration) }
    let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }

    before do
      allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false,
                                        request_types: %i[get put post delete],
                                        pagination_timeout_seconds: 45)
      allow(service).to receive_messages(config:)
      allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
    end

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

    context 'when Eps::ServiceException is raised' do
      let(:eps_exception) do
        create_eps_exception(
          code: 'VAOS_401',
          status: 401,
          body: '{"name": "Unauthorized"}'
        )
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(eps_exception)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs EPS error with sanitized context and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: EPS service error',
          hash_including(
            service: 'EPS',
            method: 'get_provider_service',
            error_class: 'Eps::ServiceException',
            timestamp: a_string_matching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
            code: 'VAOS_401',
            upstream_status: 401,
            upstream_body: '{\"name\": \"Unauthorized\"}'
          )
        )

        expect do
          service.get_provider_service(provider_id:)
        end.to raise_error(Eps::ServiceException)
      end
    end

    context 'when provider_id parameter is missing or blank' do
      it 'raises ArgumentError and logs StatsD metric and Rails warning when provider_id is nil' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_service.no_params',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Provider service called with no parameters',
          hash_including(
            method: 'get_provider_service',
            service: 'eps_provider_service',
            user_uuid: 'user-uuid-123'
          )
        )

        expect do
          service.get_provider_service(provider_id: nil)
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end

      it 'raises ArgumentError and logs StatsD metric and Rails warning when provider_id is empty string' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_service.no_params',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Provider service called with no parameters',
          hash_including(
            method: 'get_provider_service',
            service: 'eps_provider_service',
            user_uuid: 'user-uuid-123'
          )
        )

        expect do
          service.get_provider_service(provider_id: '')
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end

      it 'raises ArgumentError and logs StatsD metric and Rails warning when provider_id is blank' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_service.no_params',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Provider service called with no parameters',
          hash_including(
            method: 'get_provider_service',
            service: 'eps_provider_service',
            user_uuid: 'user-uuid-123'
          )
        )

        expect do
          service.get_provider_service(provider_id: '   ')
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end
    end
  end

  describe '#get_networks' do
    let(:config) { instance_double(Eps::Configuration) }
    let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }

    before do
      allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false,
                                        request_types: %i[get put post delete])
      allow(service).to receive_messages(config:)
      allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
    end

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

    context 'when Eps::ServiceException is raised' do
      let(:eps_exception) do
        create_eps_exception(
          code: 'VAOS_500',
          status: 500,
          body: '{"error": "Internal Service Exception"}'
        )
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(eps_exception)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs EPS error with sanitized context and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: EPS service error',
          hash_including(
            service: 'EPS',
            method: 'get_networks',
            error_class: 'Eps::ServiceException',
            timestamp: a_string_matching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
            code: 'VAOS_500',
            upstream_status: 500,
            upstream_body: '{\"error\": \"Internal Service Exception\"}'
          )
        )

        expect do
          service.get_networks
        end.to raise_error(Eps::ServiceException)
      end
    end
  end

  describe '#get_provider_services_by_ids' do
    let(:provider_ids) { %w[provider1 provider2] }
    let(:config) { instance_double(Eps::Configuration) }
    let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }

    before do
      allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false,
                                        request_types: %i[get put post delete])
      allow(service).to receive_messages(config:)
      allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
    end

    context 'when the request is successful' do
      let(:response) do
        double('Response', status: 200, body: {
                 count: 2,
                 provider_services: [
                   { id: 'provider1', name: 'Provider 1' },
                   { id: 'provider2', name: 'Provider 2' }
                 ]
               }, response_headers: { 'Content-Type' => 'application/json' })
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
      end

      it 'returns an OpenStruct with the response body' do
        result = service.get_provider_services_by_ids(provider_ids:)

        expect(result).to eq(OpenStruct.new(response.body))
      end

      it 'calls perform with multiple id parameters as required by backend' do
        expected_url = '/api/v1/provider-services?id=provider1&id=provider2'
        expect_any_instance_of(VAOS::SessionService).to receive(:perform).with(
          :get,
          expected_url,
          {},
          headers
        ).and_return(response)

        service.get_provider_services_by_ids(provider_ids:)
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
          service.get_provider_services_by_ids(provider_ids:)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end

    context 'when Eps::ServiceException is raised' do
      let(:eps_exception) do
        create_eps_exception(
          code: 'VAOS_401',
          status: 401,
          body: '{"name": "Unauthorized"}'
        )
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(eps_exception)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs EPS error with sanitized context and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: EPS service error',
          hash_including(
            service: 'EPS',
            method: 'get_provider_services_by_ids',
            error_class: 'Eps::ServiceException',
            timestamp: a_string_matching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
            code: 'VAOS_401',
            upstream_status: 401,
            upstream_body: '{\"name\": \"Unauthorized\"}'
          )
        )

        expect do
          service.get_provider_services_by_ids(provider_ids:)
        end.to raise_error(Eps::ServiceException)
      end
    end

    context 'when provider_ids parameter is missing or blank' do
      it 'returns empty provider_services and logs StatsD metric and Rails warning when provider_ids is nil' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_service.no_params',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Provider service called with no parameters',
          hash_including(
            method: 'get_provider_services_by_ids',
            service: 'eps_provider_service'
          )
        )

        result = service.get_provider_services_by_ids(provider_ids: nil)
        expect(result).to eq(OpenStruct.new(provider_services: []))
      end

      it 'returns empty provider_services and logs StatsD metric and Rails warning when provider_ids is empty array' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_service.no_params',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Provider service called with no parameters',
          hash_including(
            method: 'get_provider_services_by_ids',
            service: 'eps_provider_service'
          )
        )

        result = service.get_provider_services_by_ids(provider_ids: [])
        expect(result).to eq(OpenStruct.new(provider_services: []))
      end
    end
  end

  describe 'get_drive_times' do
    let(:config) { instance_double(Eps::Configuration) }
    let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }
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

    before do
      allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false,
                                        request_types: %i[get put post delete])
      allow(service).to receive_messages(config:)
      allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
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

    context 'when Eps::ServiceException is raised' do
      let(:eps_exception) do
        create_eps_exception(
          code: 'VAOS_400',
          status: 400,
          body: '{"name":"invalid_range","id":"aVFqt9NH",' \
                '"message":"body.latitude must be lesser or equal than 90 but got value 91",' \
                '"temporary":false,"timeout":false,"fault":false}'
        )
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(eps_exception)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs EPS error with sanitized context and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: EPS service error',
          hash_including(
            service: 'EPS',
            method: 'get_drive_times',
            error_class: 'Eps::ServiceException',
            timestamp: a_string_matching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
            code: 'VAOS_400',
            upstream_status: 400,
            upstream_body: '{\"name\":\"invalid_range\",\"id\":\"aVFqt9NH\",' \
                           '\"message\":\"body.latitude must be lesser or equal than 90 but got value 91\",' \
                           '\"temporary\":false,\"timeout\":false,\"fault\":false}'
          )
        )

        expect do
          service.get_drive_times(destinations:, origin:)
        end.to raise_error(Eps::ServiceException)
      end
    end
  end

  describe '#get_provider_slots' do
    let(:provider_id) { '9mN718pH' }
    let(:required_params) do
      {
        appointmentTypeId: 'type123',
        startOnOrAfter: '2024-01-01T00:00:00Z',
        startBefore: '2024-01-02T00:00:00Z',
        appointmentId: '123'
      }
    end

    context 'when provider_id is invalid' do
      let(:config) { instance_double(Eps::Configuration) }
      let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }

      before do
        allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false,
                                          request_types: %i[get put post delete],
                                          pagination_timeout_seconds: 45)
        allow(service).to receive_messages(config:)
        allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
      end

      it 'raises ArgumentError when provider_id is nil' do
        expect do
          service.get_provider_slots(nil, required_params)
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end

      it 'raises ArgumentError when provider_id is empty' do
        expect do
          service.get_provider_slots('', required_params)
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end

      it 'raises ArgumentError when provider_id is blank' do
        expect do
          service.get_provider_slots('   ', required_params)
        end.to raise_error(ArgumentError, 'provider_id is required and cannot be blank')
      end
    end

    context 'when required parameters are missing' do
      let(:config) { instance_double(Eps::Configuration) }
      let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }

      before do
        allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false,
                                          request_types: %i[get put post delete],
                                          pagination_timeout_seconds: 45)
        allow(service).to receive_messages(config:)
        allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
      end

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

      it 'raises ArgumentError when appointmentId is missing' do
        expect do
          service.get_provider_slots(provider_id, required_params.except(:appointmentId))
        end.to raise_error(ArgumentError, /Missing required parameters: appointmentId/)
      end

      it 'raises ArgumentError when multiple required parameters are missing' do
        expect do
          service.get_provider_slots(provider_id, required_params.except(:startOnOrAfter, :startBefore))
        end.to raise_error(ArgumentError, /Missing required parameters: startOnOrAfter, startBefore/)
      end
    end

    context 'when single page response (no pagination)', :vcr do
      it 'returns an OpenStruct with all slots and correct count' do
        VCR.use_cassette('vaos/eps/get_provider_slots/200') do
          result = service.get_provider_slots('Aq7wgAux', {
                                                appointmentTypeId: 'ov',
                                                startOnOrAfter: '2025-01-01T00:00:00Z',
                                                startBefore: '2025-01-03T00:00:00Z',
                                                appointmentId: '123'
                                              })

          expect(result).to be_a(OpenStruct)
          expect(result.slots.length).to eq(2)
          expect(result.count).to eq(2)
          expect(result.slots.first[:id]).to include('5vuTac8v-practitioner')
        end
      end

      it 'removes nextToken from response' do
        VCR.use_cassette('vaos/eps/get_provider_slots/200') do
          result = service.get_provider_slots('Aq7wgAux', {
                                                appointmentTypeId: 'ov',
                                                startOnOrAfter: '2025-01-01T00:00:00Z',
                                                startBefore: '2025-01-03T00:00:00Z',
                                                appointmentId: '123'
                                              })

          expect(result.to_h).not_to have_key(:next_token)
          expect(result.to_h).not_to have_key(:nextToken)
        end
      end
    end

    context 'when empty response', :vcr do
      it 'returns empty slots array with zero count' do
        VCR.use_cassette('vaos/eps/get_provider_slots/200_no_slots') do
          result = service.get_provider_slots('9mN718pH', {
                                                appointmentTypeId: 'ov',
                                                startOnOrAfter: '2025-01-01T00:00:00Z',
                                                startBefore: '2025-01-03T00:00:00Z',
                                                appointmentId: '123'
                                              })

          expect(result.slots).to eq([])
          expect(result.count).to eq(0)
        end
      end
    end

    context 'when pagination timeout occurs' do
      it 'raises BackendServiceException when timeout exceeded using VCR', :vcr do
        # Use Timecop to simulate timeout during pagination
        Timecop.freeze(Time.zone.parse('2024-01-01 12:00:00')) do
          expect(Rails.logger).to receive(:error)

          # Simulate time advancing during the API call
          allow_any_instance_of(VAOS::SessionService).to receive(:perform) do
            Timecop.travel(46.seconds) # Advance time to trigger timeout
            # Return a response that would normally continue pagination
            double('Response', body: { slots: [{ id: 'test' }], next_token: 'token123' })
          end

          VCR.use_cassette('vaos/eps/get_provider_slots/timeout_simulation') do
            expect do
              service.get_provider_slots('TIMEOUT_TEST', {
                                           appointmentTypeId: 'ov',
                                           startOnOrAfter: '2025-01-01T00:00:00Z',
                                           startBefore: '2025-01-03T00:00:00Z',
                                           appointmentId: '123'
                                         })
            end.to raise_error(Common::Exceptions::BackendServiceException) { |error|
              expect(error.key).to eq('PROVIDER_SLOTS_TIMEOUT')
            }
          end
        end
      end
    end

    context 'when API request fails' do
      let(:config) { instance_double(Eps::Configuration) }
      let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, 500, 'Unknown service exception')
      end

      before do
        allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false,
                                          request_types: %i[get put post delete],
                                          pagination_timeout_seconds: 45)
        allow(service).to receive_messages(config:)
        allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'raises the original exception' do
        expect do
          service.get_provider_slots(provider_id, required_params)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end

    context 'when multiple page response (with pagination)', :vcr do
      it 'handles pagination from VCR cassette' do
        VCR.use_cassette('vaos/eps/get_provider_slots/200_with_pagination') do
          result = service.get_provider_slots('TEST123', {
                                                appointmentTypeId: 'ov',
                                                startOnOrAfter: '2025-01-01T00:00:00Z',
                                                startBefore: '2025-01-03T00:00:00Z',
                                                appointmentId: '123'
                                              })

          expect(result).to be_a(OpenStruct)
          expect(result.slots.length).to eq(3)
          expect(result.count).to eq(3)
          expect(result.slots.map { |slot| slot[:id] }).to include(
            'page1-slot1|2025-01-02T09:00:00Z',
            'page1-slot2|2025-01-02T10:00:00Z',
            'page3-slot1|2025-01-02T14:00:00Z'
          )
          expect(result.to_h).not_to have_key(:next_token)
        end
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

    context 'when required parameters are missing or blank' do
      it 'raises ArgumentError and logs personal information when npi is nil' do
        expect(PersonalInformationLog).to receive(:create).with(
          error_class: 'eps_provider_npi_missing',
          data: hash_including(
            search_params: hash_including(specialty:),
            failure_reason: 'NPI parameter is blank'
          )
        )

        expect do
          service.search_provider_services(npi: nil, specialty:, address:)
        end.to raise_error(ArgumentError, 'Provider NPI is required and cannot be blank')
      end

      it 'raises ArgumentError when npi is empty string' do
        expect do
          service.search_provider_services(npi: '', specialty:, address:)
        end.to raise_error(ArgumentError, 'Provider NPI is required and cannot be blank')
      end

      it 'raises ArgumentError when npi is blank' do
        expect do
          service.search_provider_services(npi: '   ', specialty:, address:)
        end.to raise_error(ArgumentError, 'Provider NPI is required and cannot be blank')
      end

      it 'raises ArgumentError and logs personal information when specialty is nil' do
        expect(PersonalInformationLog).to receive(:create).with(
          error_class: 'eps_provider_specialty_missing',
          data: hash_including(
            npi:,
            failure_reason: 'Specialty parameter is blank'
          )
        )

        expect do
          service.search_provider_services(npi:, specialty: nil, address:)
        end.to raise_error(ArgumentError, 'Provider specialty is required and cannot be blank')
      end

      it 'raises ArgumentError when specialty is empty string' do
        expect do
          service.search_provider_services(npi:, specialty: '', address:)
        end.to raise_error(ArgumentError, 'Provider specialty is required and cannot be blank')
      end

      it 'raises ArgumentError when specialty is blank' do
        expect do
          service.search_provider_services(npi:, specialty: '   ', address:)
        end.to raise_error(ArgumentError, 'Provider specialty is required and cannot be blank')
      end

      it 'raises ArgumentError and logs personal information when address is nil' do
        expect(PersonalInformationLog).to receive(:create).with(
          error_class: 'eps_provider_address_missing',
          data: hash_including(
            npi:,
            search_params: hash_including(specialty:),
            failure_reason: 'Address parameter is blank'
          )
        )

        expect do
          service.search_provider_services(npi:, specialty:, address: nil)
        end.to raise_error(ArgumentError, 'Provider address is required and cannot be blank')
      end

      it 'raises ArgumentError when address is empty hash' do
        expect do
          service.search_provider_services(npi:, specialty:, address: {})
        end.to raise_error(ArgumentError, 'Provider address is required and cannot be blank')
      end
    end

    context 'when the request is successful' do
      context 'when provider specialty does not match' do
        let(:response_body) do
          {
            count: 1,
            provider_services: [
              self_schedulable_provider(specialties: [{ name: 'Dermatology' }])
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

        it 'returns nil and logs personal information' do
          expect(PersonalInformationLog).to receive(:create).with(
            error_class: 'eps_provider_specialty_mismatch',
            data: hash_including(
              npi:,
              search_params: hash_including(specialty:),
              failure_reason: "No providers match specialty '#{specialty}'"
            )
          )

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

        it 'returns nil and logs personal information' do
          expect(PersonalInformationLog).to receive(:create).with(
            error_class: 'eps_provider_no_providers_found',
            data: hash_including(
              npi:,
              failure_reason: 'No providers returned from EPS API for NPI'
            )
          )

          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_nil
        end
      end

      context 'when provider has blank specialty' do
        let(:response_body) do
          {
            count: 1,
            provider_services: [
              self_schedulable_provider(specialties: [])
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

      context 'when providers are returned but none are self-schedulable' do
        let(:response_body) do
          {
            count: 2,
            provider_services: [
              {
                id: 'provider1',
                specialties: [{ name: 'Cardiology' }],
                appointment_types: [
                  {
                    name: 'Office Visit',
                    is_self_schedulable: false
                  }
                ],
                features: {
                  is_digital: true,
                  direct_booking: {
                    is_enabled: true
                  }
                },
                location: {
                  address: '1105 Palmetto Ave, Melbourne, FL, 32901'
                }
              },
              {
                id: 'provider2',
                specialties: [{ name: 'Cardiology' }],
                appointment_types: [
                  {
                    name: 'Office Visit',
                    is_self_schedulable: true
                  }
                ],
                features: {
                  is_digital: false,
                  direct_booking: {
                    is_enabled: true
                  }
                },
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
          allow(Rails.logger).to receive(:error)
        end

        it 'returns nil, logs error, increments metric, and logs personal information' do
          expect(StatsD).to receive(:increment).with(
            'api.vaos.provider_service.no_self_schedulable',
            tags: ['service:community_care_appointments']
          )
          expect(PersonalInformationLog).to receive(:create).with(
            error_class: 'eps_provider_no_self_schedulable',
            data: hash_including(
              npi:,
              failure_reason: match(/No self-schedulable providers found/)
            )
          )

          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_nil
          expected_controller_name = 'VAOS::V2::AppointmentsController'
          expected_station_number = user.va_treatment_facility_ids&.first
          expect(Rails.logger).to have_received(:error).with(
            'Community Care Appointments: No self-schedulable providers found for NPI',
            {
              controller: expected_controller_name,
              station_number: expected_station_number,
              eps_trace_id: nil,
              user_uuid: 'user-uuid-123'
            }
          )
        end
      end

      context 'when provider meets all self-schedulable criteria' do
        let(:response_body) do
          {
            count: 1,
            provider_services: [
              self_schedulable_provider
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

        it 'returns the provider' do
          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('provider123')
        end
      end

      context 'when provider fails office visit appointment type criteria' do
        let(:response_body) do
          {
            count: 1,
            provider_services: [
              self_schedulable_provider(
                appointment_types: [
                  {
                    name: 'Office Visit',
                    is_self_schedulable: false
                  }
                ]
              )
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:error)
        end

        it 'returns nil, logs error, and increments metric' do
          expect(StatsD).to receive(:increment).with(
            'api.vaos.provider_service.no_self_schedulable',
            tags: ['service:community_care_appointments']
          )
          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_nil
          expected_controller_name = 'VAOS::V2::AppointmentsController'
          expected_station_number = user.va_treatment_facility_ids&.first
          expect(Rails.logger).to have_received(:error).with(
            'Community Care Appointments: No self-schedulable providers found for NPI',
            {
              controller: expected_controller_name,
              station_number: expected_station_number,
              eps_trace_id: nil,
              user_uuid: 'user-uuid-123'
            }
          )
        end
      end

      context 'when provider fails isDigital criteria' do
        let(:response_body) do
          {
            count: 1,
            provider_services: [
              self_schedulable_provider(
                features: {
                  is_digital: false,
                  direct_booking: {
                    is_enabled: true
                  }
                }
              )
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:error)
        end

        it 'returns nil, logs error, and increments metric' do
          expect(StatsD).to receive(:increment).with(
            'api.vaos.provider_service.no_self_schedulable',
            tags: ['service:community_care_appointments']
          )
          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_nil
          expected_controller_name = 'VAOS::V2::AppointmentsController'
          expected_station_number = user.va_treatment_facility_ids&.first
          expect(Rails.logger).to have_received(:error).with(
            'Community Care Appointments: No self-schedulable providers found for NPI',
            {
              controller: expected_controller_name,
              station_number: expected_station_number,
              eps_trace_id: nil,
              user_uuid: 'user-uuid-123'
            }
          )
        end
      end

      context 'when provider fails directBooking.isEnabled criteria' do
        let(:response_body) do
          {
            count: 1,
            provider_services: [
              self_schedulable_provider(
                features: {
                  is_digital: true,
                  direct_booking: {
                    is_enabled: false
                  }
                }
              )
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:error)
        end

        it 'returns nil, logs error, and increments metric' do
          expect(StatsD).to receive(:increment).with(
            'api.vaos.provider_service.no_self_schedulable',
            tags: ['service:community_care_appointments']
          )
          result = service.search_provider_services(npi:, specialty:, address:)
          expect(result).to be_nil
          expected_controller_name = 'VAOS::V2::AppointmentsController'
          expected_station_number = user.va_treatment_facility_ids&.first
          expect(Rails.logger).to have_received(:error).with(
            'Community Care Appointments: No self-schedulable providers found for NPI',
            {
              controller: expected_controller_name,
              station_number: expected_station_number,
              eps_trace_id: nil,
              user_uuid: 'user-uuid-123'
            }
          )
        end
      end

      context 'when multiple self-schedulable providers exist' do
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
              self_schedulable_provider(
                id: 'provider1',
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              ),
              self_schedulable_provider(
                id: 'provider2',
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              )
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

        it 'returns the first matching provider' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('provider1')
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
              self_schedulable_provider(
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              )
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
            count: 2,
            provider_services: [
              self_schedulable_provider(
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              ),
              self_schedulable_provider(
                id: 'provider456',
                location: {
                  address: '2200 Oak Street, COLUMBUS, OH 43201-1234'
                }
              )
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

        it 'returns nil, logs warning, and logs personal information' do
          expect(PersonalInformationLog).to receive(:create).with(
            error_class: 'eps_provider_address_mismatch',
            data: hash_including(
              npi:,
              search_params: hash_including(specialty_matches_count: 2),
              failure_reason: match(/No address match found among 2 specialty-matched providers/)
            )
          )

          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: non_matching_address)
          expect(result).to be_nil
          expect(Rails.logger).to have_received(:warn).with(
            'Community Care Appointments: No address match found among 2 provider(s) for NPI',
            hash_including(
              specialty_matches_count: 2
            )
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
              self_schedulable_provider(
                specialties: [{ name: 'CARDIOLOGY' }],
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              )
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
              self_schedulable_provider(
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              )
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
            count: 2,
            provider_services: [
              self_schedulable_provider(
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              ),
              self_schedulable_provider(
                id: 'provider456',
                location: {
                  address: '2200 Oak Street, COLUMBUS, OH 43201-1234'
                }
              )
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
            count: 2,
            provider_services: [
              self_schedulable_provider(
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              ),
              self_schedulable_provider(
                id: 'provider456',
                location: {
                  address: '2200 Oak Street, COLUMBUS, OH 43201-1234'
                }
              )
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
            'Community Care Appointments: Provider address partial match',
            hash_including(
              street_matches: false,
              zip_matches: true
            )
          )
        end
      end

      context 'when multiple providers match specialty and address validation is performed' do
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
              self_schedulable_provider(
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              ),
              self_schedulable_provider(
                id: 'provider456',
                location: {
                  address: '2200 Oak Street, COLUMBUS, OH 43201-1234'
                }
              )
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
              self_schedulable_provider(
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              ),
              self_schedulable_provider(
                id: 'provider456',
                location: {
                  address: '2200 Oak Street, COLUMBUS, OH 43201-1234'
                }
              )
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
            'Community Care Appointments: No address match found among 2 provider(s) for NPI',
            hash_including(
              specialty_matches_count: 2
            )
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
              self_schedulable_provider(
                location: {
                  address: 'Incomplete Address'
                }
              )
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:info)
        end

        it 'returns the provider when it is the only specialty match, regardless of address parsing' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('provider123')
        end

        it 'logs that address validation was skipped' do
          service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
          expect(Rails.logger).to have_received(:info)
            .with('Single specialty match found for NPI, skipping address validation')
        end
      end

      # Test cases for zip code extraction with street addresses containing 5-digit numbers
      context 'when handling zip code extraction with various address formats' do
        let(:response_body) do
          {
            count: 3,
            provider_services: [
              self_schedulable_provider(
                id: 'provider1',
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848, US' # 4-digit street, zip+4
                }
              ),
              self_schedulable_provider(
                id: 'provider2',
                location: {
                  address: '16011 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848' # 5-digit street, zip+4
                }
              ),
              self_schedulable_provider(
                id: 'provider3',
                location: {
                  address: '16011 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414, US' # 5-digit street, 5-digit zip
                }
              )
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
                self_schedulable_provider(
                  id: 'provider_extreme',
                  location: {
                    # Extreme case: street address has 45414-3333 format, but actual zip is 12345
                    address: '45414-3333 FAKE STREET, COLUMBUS, OH 12345-6789, US'
                  }
                )
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

      context 'when only one provider matches specialty' do
        let(:any_address) do
          {
            street1: '999 Different Street',
            city: 'TOLEDO',
            state: 'Ohio',
            zip: '43604'
          }
        end

        let(:response_body) do
          {
            count: 1,
            provider_services: [
              self_schedulable_provider(
                id: 'single_provider',
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              )
            ]
          }
        end

        let(:response) do
          double('Response', status: 200, body: response_body,
                             response_headers: { 'Content-Type' => 'application/json' })
        end

        before do
          allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
          allow(Rails.logger).to receive(:info)
        end

        it 'returns the provider without address validation' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: any_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('single_provider')
        end

        it 'logs that address validation was skipped' do
          service.search_provider_services(npi:, specialty: 'Cardiology', address: any_address)
          expect(Rails.logger).to have_received(:info)
            .with('Single specialty match found for NPI, skipping address validation')
        end

        it 'returns provider even when address does not match' do
          non_matching_address = {
            street1: '999 Nowhere Street',
            city: 'TOLEDO',
            state: 'Ohio',
            zip: '43604'
          }

          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: non_matching_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('single_provider')
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
              self_schedulable_provider(
                location: {
                  address: '1601 NEEDMORE RD ; STE 1 & 2, DAYTON, OH 45414-3848'
                }
              ),
              self_schedulable_provider(
                id: 'provider456',
                location: {
                  address: '2200 Oak Street, COLUMBUS, OH 43201-1234'
                }
              )
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

        it 'performs address validation and returns matching provider' do
          result = service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
          expect(result).to be_a(OpenStruct)
          expect(result.id).to eq('provider123')
        end

        it 'does not log single match message when multiple providers exist' do
          allow(Rails.logger).to receive(:info)
          service.search_provider_services(npi:, specialty: 'Cardiology', address: matching_address)
          expect(Rails.logger).not_to have_received(:info)
            .with('Single specialty match found for NPI, skipping address validation')
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

  describe '#fetch_provider_services' do
    let(:npi) { '1234567890' }
    let(:config) { instance_double(Eps::Configuration) }
    let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }

    before do
      allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false,
                                        request_types: %i[get put post delete])
      allow(service).to receive_messages(config:)
      allow(service).to receive(:request_headers_with_correlation_id).and_return(headers)
    end

    context 'when the request is successful' do
      let(:response) do
        double('Response', status: 200, body: {
                 count: 1,
                 provider_services: [
                   { id: 'provider1', npi:, name: 'Provider 1' }
                 ]
               }, response_headers: { 'Content-Type' => 'application/json' })
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(response)
      end

      it 'returns the response from perform' do
        result = service.send(:fetch_provider_services, npi)

        expect(result).to eq(response)
      end

      it 'calls perform with correct parameters' do
        expect_any_instance_of(VAOS::SessionService).to receive(:perform).with(
          :get,
          '/api/v1/provider-services',
          { npi: },
          headers
        ).and_return(response)

        service.send(:fetch_provider_services, npi)
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
          service.send(:fetch_provider_services, npi)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end

    context 'when npi parameter is missing or blank' do
      it 'raises ArgumentError and logs StatsD metric and Rails warning when npi is nil' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_service.no_params',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Provider service called with no parameters',
          hash_including(
            method: 'fetch_provider_services',
            service: 'eps_provider_service'
          )
        )

        expect do
          service.send(:fetch_provider_services, nil)
        end.to raise_error(ArgumentError, 'npi is required and cannot be blank')
      end

      it 'raises ArgumentError and logs StatsD metric and Rails warning when npi is empty string' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_service.no_params',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Provider service called with no parameters',
          hash_including(
            method: 'fetch_provider_services',
            service: 'eps_provider_service'
          )
        )

        expect do
          service.send(:fetch_provider_services, '')
        end.to raise_error(ArgumentError, 'npi is required and cannot be blank')
      end

      it 'raises ArgumentError and logs StatsD metric and Rails warning when npi is blank' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_service.no_params',
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Provider service called with no parameters',
          hash_including(
            method: 'fetch_provider_services',
            service: 'eps_provider_service'
          )
        )

        expect do
          service.send(:fetch_provider_services, '   ')
        end.to raise_error(ArgumentError, 'npi is required and cannot be blank')
      end
    end
  end

  # Helper method to create a self-schedulable provider
  def self_schedulable_provider(overrides = {})
    {
      id: 'provider123',
      specialties: [{ name: 'Cardiology' }],
      appointment_types: [
        {
          name: 'Office Visit',
          is_self_schedulable: true
        }
      ],
      features: {
        is_digital: true,
        direct_booking: {
          is_enabled: true
        }
      },
      location: {
        address: '1105 Palmetto Ave, Melbourne, FL, 32901'
      }
    }.merge(overrides)
  end

  # Helper method to create EPS exceptions with properly formatted messages
  def create_eps_exception(code:, status:, body:)
    exception = Eps::ServiceException.new(
      code,
      { code:, detail: 'Test error' },
      status,
      body
    )
    # Mock the message to include the parseable format for parse_eps_backend_fields
    allow(exception).to receive(:message).and_return(
      "BackendServiceException: {:code=>\"#{code}\", " \
      ":source=>{:vamf_status=>#{status}, :vamf_body=>#{body.inspect}}}"
    )
    exception
  end
end
