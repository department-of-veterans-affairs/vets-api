# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Health::Locations', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '9000682') }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
    allow_any_instance_of(Mobile::V0::LighthouseAssertion).to receive(:rsa_key).and_return(
      OpenSSL::PKey::RSA.new(rsa_key.to_s)
    )
  end

  after do
    Timecop.return
  end

  describe 'GET /mobile/v0/health/locations/:id' do
    context 'When a valid ID is provided' do
      before do
        VCR.use_cassette('mobile/lighthouse_health/get_lh_location', match_requests_on: %i[method uri]) do
          VCR.use_cassette('lighthouse/facilities/v1/200_facilities') do
            get '/mobile/v0/health/locations/I2-3JYDMXC6RXTU4H25KRVXATSEJQ000000', headers: sis_headers
          end
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches json schema' do
        # expect(response.parsed_body).to match_json_schema('immunization_location')
        expect(response.parsed_body).to eq({ 'data' =>
                                               { 'id' => 'I2-3JYDMXC6RXTU4H25KRVXATSEJQ000000',
                                                 'type' => 'location',
                                                 'attributes' => {
                                                   'name' => 'Cheyenne VA Medical Center',
                                                   'address' => {
                                                     'street' => '2360 East Pershing Boulevard',
                                                     'city' => 'Cheyenne',
                                                     'state' => 'WY',
                                                     'zipCode' => '82001-5356'
                                                   }
                                                 } } })
      end
    end
  end

  context 'When the facilities endpoint fails to find the location' do
    before do
      VCR.use_cassette('mobile/lighthouse_health/get_facility_v1_empty_442', match_requests_on: %i[method uri]) do
        VCR.use_cassette('mobile/lighthouse_health/get_lh_location', match_requests_on: %i[method uri]) do
          get '/mobile/v0/health/locations/I2-3JYDMXC6RXTU4H25KRVXATSEJQ000000', headers: sis_headers
        end
      end
    end

    it 'returns a 404' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'When lh location returns 404' do
    before do
      VCR.use_cassette('mobile/lighthouse_health/get_lh_location_404', match_requests_on: %i[method uri]) do
        get '/mobile/v0/health/locations/FAKE-ID', headers: sis_headers
      end
    end

    it 'returns a 404' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'When lh location has no identifier' do
    before do
      VCR.use_cassette('mobile/lighthouse_health/get_lh_location_no_identifier', match_requests_on: %i[method uri]) do
        get '/mobile/v0/health/locations/I2-3JYDMXC6RXTU4H25KRVXATSEJQ000000', headers: sis_headers
      end
    end

    it 'returns a 400' do
      expect(response).to have_http_status(:bad_request)
    end
  end
end
