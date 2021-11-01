# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'immunizations', type: :request do
  include JsonSchemaMatchers

  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  before do
    allow(File).to receive(:read).and_return(rsa_key.to_s)
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('9000682')
    iam_sign_in(build(:iam_user))
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
  end

  after { Timecop.return }

  describe 'GET /mobile/v0/health/location/:id' do
    context 'When a valid ID is provided' do
      before do
        VCR.use_cassette('lighthouse_health/get_facility', match_requests_on: %i[method uri]) do
          VCR.use_cassette('lighthouse_health/get_lh_location', match_requests_on: %i[method uri]) do
            get '/mobile/v0/health/location/I2-3JYDMXC6RXTU4H25KRVXATSEJQ000000', headers: iam_headers
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
                                                   'name' => 'COLUMBUS VAMC',
                                                   'address' => {
                                                     'street' => '2360 East Pershing Boulevard',
                                                     'city' => 'Columbus',
                                                     'state' => 'OH',
                                                     'zipCode' => '82001-5356'
                                                   }
                                                 } } })
      end
    end
  end

  context 'When the facilities endpoint fails to find the location' do
    before do
      VCR.use_cassette('lighthouse_health/get_facilities_empty', match_requests_on: %i[method uri]) do
        VCR.use_cassette('lighthouse_health/get_lh_location', match_requests_on: %i[method uri]) do
          get '/mobile/v0/health/location/I2-3JYDMXC6RXTU4H25KRVXATSEJQ000000', headers: iam_headers
        end
      end
    end

    it 'returns a 404' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'When lh location returns 404' do
    before do
      VCR.use_cassette('lighthouse_health/get_lh_location_404', match_requests_on: %i[method uri]) do
        get '/mobile/v0/health/location/FAKE-ID', headers: iam_headers
      end
    end

    it 'returns a 404' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
