# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/ppms/ppms',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'FacilitiesApi::V2::Ccp', team: :facilities, type: :request, vcr: vcr_options do
  before(:all) do
    get facilities_api.v2_ccp_index_url
  end

  let(:sha256) { 'bd2b84cc5c0aa3676090eacde32e99c7d668388e5fc5440e3c582aef419fc398' }

  let(:params) do
    {
      lat: 40.415217,
      long: -74.057114,
      radius: 200,
      type: 'provider',
      specialties: ['213E00000X']
    }
  end

  let(:place_of_service) do
    {
      'id' => '1a2ec66b370936eccc980db2fcf4b094fc61a5329aea49744d538f6a9bab2569',
      'type' => 'provider',
      'attributes' =>
       {
         'accNewPatients' => 'false',
         'address' => {
           'street' => '2 BAYSHORE PLZ',
           'city' => 'ATLANTIC HIGHLANDS',
           'state' => 'NJ',
           'zip' => '07716'
         },
         'caresitePhone' => '732-291-2900',
         'email' => nil,
         'fax' => nil,
         'gender' => 'NotSpecified',
         'lat' => 40.409114,
         'long' => -74.041849,
         'name' => 'BAYSHORE PHARMACY',
         'phone' => nil,
         'posCodes' => '17',
         'prefContact' => nil,
         'trainings' => [],
         'uniqueId' => '1225028293'
       }
    }
  end

  describe '#index' do
    context 'Empty Results', vcr: vcr_options.merge(
      cassette_name: 'facilities/ppms/ppms_empty_search',
      match_requests_on: [:method]
    ) do
      it 'responds to GET #index with success even if no providers are found' do
        get('/facilities_api/v2/ccp', params:)

        expect(response).to be_successful
      end
    end

    context 'type=provider' do
      context 'Missing specialties param' do
        let(:params) do
          {
            lat: 40.415217,
            long: -74.057114,
            radius: 200,
            type: 'provider'
          }
        end

        it 'requires a specialty code' do
          get('/facilities_api/v2/ccp', params:)

          bod = JSON.parse(response.body)

          expect(bod).to include(
            'errors' => [
              {
                'title' => 'Missing parameter',
                'detail' => 'The required parameter "specialties", is missing',
                'code' => '108',
                'status' => '400'
              }
            ]
          )

          expect(response).not_to be_successful
        end
      end

      context 'specialties=261QU0200X' do
        let(:params) do
          {
            lat: 40.415217,
            long: -74.057114,
            radius: 200,
            type: 'provider',
            specialties: ['261QU0200X']
          }
        end

        it 'returns a results from the pos_locator' do
          get('/facilities_api/v2/ccp', params:)

          bod = JSON.parse(response.body)

          expect(bod['data']).to include(place_of_service)

          expect(response).to be_successful
        end
      end

      it "sends a 'facilities.ppms.v2.request.faraday' notification to any subscribers listening" do
        allow(StatsD).to receive(:measure)

        expect(StatsD).to receive(:measure).with(
          'facilities.ppms.facility_service_locator',
          kind_of(Numeric),
          hash_including(
            tags: [
              'facilities.ppms',
              'facilities.ppms.radius:200',
              'facilities.ppms.results:10'
            ]
          )
        )

        expect do
          get '/facilities_api/v2/ccp', params:
        end.to instrument('facilities.ppms.v2.request.faraday')
      end

      [
        [1, 20],
        [2, 20],
        [3, 20]
      ].each do |(page, per_page, _total_entries)|
        it "paginates ppms responses (page: #{page}, per_page: #{per_page}" do
          params_with_pagination = params.merge(
            page: page.to_s,
            per_page: per_page.to_s
          )

          get '/facilities_api/v2/ccp', params: params_with_pagination
          bod = JSON.parse(response.body)

          prev_page = page == 1 ? nil : page - 1
          expect(bod['meta']).to include(
            'pagination' => {
              'current_page' => page,
              'prev_page' => prev_page,
              'next_page' => page + 1,
              'total_pages' => 120,
              'total_entries' => 2394
            }
          )
        end
      end

      it 'returns a results from the provider_locator' do
        get('/facilities_api/v2/ccp', params:)

        bod = JSON.parse(response.body)
        expect(bod['data']).to include(
          {
            'id' => '6d4644e7db7491635849b23e20078f74cfcd2d0aeee6a77aca921f5540d03f33',
            'type' => 'provider',
            'attributes' => {
              'accNewPatients' => 'true',
              'address' => {
                'street' => '176 RIVERSIDE AVE',
                'city' => 'RED BANK',
                'state' => 'NJ',
                'zip' => '07701-1063'
              },
              'caresitePhone' => '732-219-6625',
              'email' => nil,
              'fax' => nil,
              'gender' => 'Female',
              'lat' => 40.35396,
              'long' => -74.07492,
              'name' => 'GESUALDI, AMY',
              'phone' => nil,
              'posCodes' => nil,
              'prefContact' => nil,
              'trainings' => [],
              'uniqueId' => '1154383230'
            }
          }
        )

        expect(response).to be_successful
      end
    end

    context 'type=pharmacy' do
      let(:params) do
        {
          lat: 40.415217,
          long: -74.057114,
          radius: 200,
          type: 'pharmacy'
        }
      end

      it 'returns results from the pos_locator' do
        get('/facilities_api/v2/ccp', params:)

        bod = JSON.parse(response.body)

        expect(bod['data'][0]).to match(
          {
            'id' => '1a2ec66b370936eccc980db2fcf4b094fc61a5329aea49744d538f6a9bab2569',
            'type' => 'provider',
            'attributes' => {
              'accNewPatients' => 'false',
              'address' => {
                'street' => '2 BAYSHORE PLZ',
                'city' => 'ATLANTIC HIGHLANDS',
                'state' => 'NJ',
                'zip' => '07716'
              },
              'caresitePhone' => '732-291-2900',
              'email' => nil,
              'fax' => nil,
              'gender' => 'NotSpecified',
              'lat' => 40.409114,
              'long' => -74.041849,
              'name' => 'BAYSHORE PHARMACY',
              'phone' => nil,
              'posCodes' => nil,
              'prefContact' => nil,
              'trainings' => [],
              'uniqueId' => '1225028293'
            }
          }
        )

        expect(response).to be_successful
      end
    end

    context 'type=urgent_care' do
      let(:params) do
        {
          lat: 40.415217,
          long: -74.057114,
          radius: 200,
          type: 'urgent_care'
        }
      end

      it 'returns results from the pos_locator' do
        get('/facilities_api/v2/ccp', params:)

        bod = JSON.parse(response.body)

        expect(bod['data']).to include(place_of_service)

        expect(response).to be_successful
      end
    end
  end

  describe '#provider' do
    context 'Missing specialties param' do
      let(:params) do
        {
          lat: 40.415217,
          long: -74.057114,
          radius: 200
        }
      end

      it 'requires a specialty code' do
        get('/facilities_api/v2/ccp/provider', params:)

        bod = JSON.parse(response.body)

        expect(bod).to include(
          'errors' => [
            {
              'title' => 'Missing parameter',
              'detail' => 'The required parameter "specialties", is missing',
              'code' => '108',
              'status' => '400'
            }
          ]
        )

        expect(response).not_to be_successful
      end
    end

    context 'specialties=261QU0200X' do
      let(:params) do
        {
          lat: 40.415217,
          long: -74.057114,
          radius: 200,
          specialties: ['261QU0200X']
        }
      end

      it 'returns a results from the pos_locator' do
        get('/facilities_api/v2/ccp/provider', params:)

        bod = JSON.parse(response.body)

        expect(bod['data']).to include(place_of_service)

        expect(response).to be_successful
      end
    end

    it 'returns a results from the provider_locator' do
      get('/facilities_api/v2/ccp/provider', params:)

      bod = JSON.parse(response.body)
      expect(bod['data']).to include(
        {
          'id' => '6d4644e7db7491635849b23e20078f74cfcd2d0aeee6a77aca921f5540d03f33',
          'type' => 'provider',
          'attributes' => {
            'accNewPatients' => 'true',
            'address' => {
              'street' => '176 RIVERSIDE AVE',
              'city' => 'RED BANK',
              'state' => 'NJ',
              'zip' => '07701-1063'
            },
            'caresitePhone' => '732-219-6625',
            'email' => nil,
            'fax' => nil,
            'gender' => 'Female',
            'lat' => 40.35396,
            'long' => -74.07492,
            'name' => 'GESUALDI, AMY',
            'phone' => nil,
            'posCodes' => nil,
            'prefContact' => nil,
            'trainings' => [],
            'uniqueId' => '1154383230'
          }
        }
      )

      expect(response).to be_successful
    end
  end

  describe '#pharmacy' do
    let(:params) do
      {
        lat: 40.415217,
        long: -74.057114,
        radius: 200
      }
    end

    it 'returns results from the pos_locator' do
      get('/facilities_api/v2/ccp/pharmacy', params:)

      bod = JSON.parse(response.body)

      expect(bod['data'][0]).to match(
        {
          'id' => '1a2ec66b370936eccc980db2fcf4b094fc61a5329aea49744d538f6a9bab2569',
          'type' => 'provider',
          'attributes' => {
            'accNewPatients' => 'false',
            'address' => {
              'street' => '2 BAYSHORE PLZ',
              'city' => 'ATLANTIC HIGHLANDS',
              'state' => 'NJ',
              'zip' => '07716'
            },
            'caresitePhone' => '732-291-2900',
            'email' => nil,
            'fax' => nil,
            'gender' => 'NotSpecified',
            'lat' => 40.409114,
            'long' => -74.041849,
            'name' => 'BAYSHORE PHARMACY',
            'phone' => nil,
            'posCodes' => nil,
            'prefContact' => nil,
            'trainings' => [],
            'uniqueId' => '1225028293'
          }
        }
      )

      expect(response).to be_successful
    end
  end

  describe '#urgent_care' do
    let(:params) do
      {
        lat: 40.415217,
        long: -74.057114,
        radius: 200
      }
    end

    it 'returns results from the pos_locator' do
      get('/facilities_api/v2/ccp/urgent_care', params:)

      bod = JSON.parse(response.body)

      expect(bod['data']).to include(place_of_service)

      expect(response).to be_successful
    end
  end

  describe '#specialties', vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
    it 'returns a list of available specializations' do
      get '/facilities_api/v2/ccp/specialties'

      bod = JSON.parse(response.body)

      expect(bod['data'][0..1]).to match(
        [
          {
            'id' => '101Y00000X',
            'type' => 'specialty',
            'attributes' => {
              'classification' => 'Counselor',
              'grouping' => 'Behavioral Health & Social Service Providers',
              'name' => 'Counselor',
              'specialization' => nil,
              'specialtyCode' => '101Y00000X',
              'specialtyDescription' => 'A provider who is trained and educated in the performance of behavior ' \
                                        'health services through interpersonal communications and analysis. ' \
                                        'Training and education at the specialty level usually requires a ' \
                                        'master\'s degree and clinical experience and supervision for licensure ' \
                                        'or certification.'
            }
          },
          {
            'id' => '101YA0400X',
            'type' => 'specialty',
            'attributes' => {
              'classification' => 'Counselor',
              'grouping' => 'Behavioral Health & Social Service Providers',
              'name' => 'Counselor - Addiction (Substance Use Disorder)',
              'specialization' => 'Addiction (Substance Use Disorder)',
              'specialtyCode' => '101YA0400X',
              'specialtyDescription' => 'Definition to come...'
            }
          }
        ]
      )
    end
  end

  describe 'Error Handling' do
    describe '#index' do
      context 'when PPMS API returns RecordNotFound' do
        it 'returns 404 error with sanitized response' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Common::Exceptions::RecordNotFound.new('id'))

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:not_found)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Not Found')
          expect(response_json['errors'].first['code']).to eq('404')
        end
      end

      context 'when PPMS API returns ResourceNotFound' do
        it 'returns 404 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Faraday::ResourceNotFound.new('response'))

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }
          bod = JSON.parse(response.body)
          expect(bod).to include('errors')
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when PPMS API times out' do
        it 'returns 504 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Faraday::TimeoutError.new)

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:gateway_timeout)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Gateway Timeout')
        end
      end

      context 'when PPMS API has net read timeout' do
        it 'returns 504 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Net::ReadTimeout.new)

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:gateway_timeout)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Gateway Timeout')
        end
      end

      context 'when PPMS API raises GatewayTimeout' do
        it 'returns 504 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Common::Exceptions::GatewayTimeout.new)

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:gateway_timeout)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Gateway Timeout')
          expect(response_json['errors'].first['code']).to eq('504')
        end
      end

      context 'when PPMS API is unavailable' do
        it 'returns 503 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Common::Exceptions::ServiceUnavailable.new)

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:service_unavailable)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Service Unavailable')
        end
      end

      context 'when PPMS API has backend error' do
        it 'returns 502 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Common::Exceptions::BackendServiceException.new)

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:bad_gateway)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Bad Gateway')
        end
      end

      context 'when PPMS API raises ClientError' do
        it 'returns 502 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Common::Client::Errors::ClientError.new('Connection failed'))

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:bad_gateway)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Bad Gateway')
          expect(response_json['errors'].first['code']).to eq('502')
        end
      end

      context 'when PPMS API raises ParsingError' do
        it 'returns 502 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Common::Client::Errors::ParsingError.new('Invalid JSON response'))

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:bad_gateway)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Bad Gateway')
          expect(response_json['errors'].first['code']).to eq('502')
        end
      end

      context 'when an unexpected error occurs' do
        it 'returns 500 error and tracks in Datadog' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(RuntimeError.new('Unexpected failure'))

          mock_span = instance_double(Datadog::Tracing::Span)
          allow(Datadog::Tracing).to receive(:active_span).and_return(mock_span)
          allow(mock_span).to receive(:set_error)
          allow(mock_span).to receive(:service=)

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:internal_server_error)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Internal server error')
          expect(response_json['errors'].first['code']).to eq('500')
          expect(mock_span).to have_received(:set_error).with(instance_of(RuntimeError))
        end

        it 'handles missing Datadog span gracefully' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(RuntimeError.new('Unexpected failure'))

          allow(Datadog::Tracing).to receive(:active_span).and_return(nil)

          get '/facilities_api/v2/ccp',
              params: { lat: 40.0, long: -74.0, type: 'provider', specialties: ['213E00000X'] }

          expect(response).to have_http_status(:internal_server_error)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Internal server error')
        end
      end
    end

    describe '#urgent_care' do
      context 'when API call fails with RecordNotFound' do
        it 'returns 404 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:pos_locator)
            .and_raise(Common::Exceptions::RecordNotFound.new('id'))

          get '/facilities_api/v2/ccp/urgent_care', params: { lat: 40.0, long: -74.0 }

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when API call fails with timeout' do
        it 'returns 504 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:pos_locator)
            .and_raise(Faraday::TimeoutError.new)

          get '/facilities_api/v2/ccp/urgent_care', params: { lat: 40.0, long: -74.0 }

          expect(response).to have_http_status(:gateway_timeout)
        end
      end

      context 'when API call fails with service unavailable' do
        it 'returns 503 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:pos_locator)
            .and_raise(Common::Exceptions::ServiceUnavailable.new)

          get '/facilities_api/v2/ccp/urgent_care', params: { lat: 40.0, long: -74.0 }

          expect(response).to have_http_status(:service_unavailable)
        end
      end

      context 'when API call fails with timeout (provider_urgent_care scenario)' do
        it 'returns 504 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:pos_locator)
            .and_raise(Common::Exceptions::Timeout.new('service'))

          get '/facilities_api/v2/ccp/provider', params: { lat: 40.0, long: -74.0, specialties: ['261QU0200X'] }

          expect(response).to have_http_status(:gateway_timeout)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Gateway Timeout')
        end
      end
    end

    describe '#provider' do
      context 'when API call fails with Faraday::ResourceNotFound' do
        it 'returns 404 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:provider_locator)
            .and_raise(Faraday::ResourceNotFound.new('response'))

          get '/facilities_api/v2/ccp/provider', params: { lat: 40.0, long: -74.0, specialties: ['213E00000X'] }

          expect(response).to have_http_status(:not_found)
          bod = JSON.parse(response.body)
          expect(bod).to include('errors')
        end
      end
    end

    describe '#pharmacy' do
      context 'when API call fails with BackendServiceException' do
        it 'returns 502 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Common::Exceptions::BackendServiceException.new)

          get '/facilities_api/v2/ccp/pharmacy', params: { lat: 40.0, long: -74.0 }

          expect(response).to have_http_status(:bad_gateway)
        end
      end

      context 'when API call fails with service unavailable' do
        it 'returns 503 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:facility_service_locator)
            .and_raise(Common::Exceptions::ServiceUnavailable.new)

          get '/facilities_api/v2/ccp/pharmacy', params: { lat: 40.0, long: -74.0 }

          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end

    describe '#specialties' do
      context 'when API call fails with timeout' do
        it 'returns 504 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:specialties)
            .and_raise(Net::ReadTimeout.new)

          get '/facilities_api/v2/ccp/specialties'

          expect(response).to have_http_status(:gateway_timeout)
          response_json = JSON.parse(response.body)
          expect(response_json['errors'].first['title']).to eq('Gateway Timeout')
        end
      end

      context 'when API call fails with service unavailable' do
        it 'returns 503 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:specialties)
            .and_raise(Common::Exceptions::ServiceUnavailable.new)

          get '/facilities_api/v2/ccp/specialties'

          expect(response).to have_http_status(:service_unavailable)
        end
      end

      context 'when API call fails with backend error' do
        it 'returns 502 error' do
          allow_any_instance_of(FacilitiesApi::V2::PPMS::Client).to receive(:specialties)
            .and_raise(Common::Exceptions::BackendServiceException.new)

          get '/facilities_api/v2/ccp/specialties'

          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end
  end
end
