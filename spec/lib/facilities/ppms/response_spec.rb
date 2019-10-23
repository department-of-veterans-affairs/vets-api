# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/response'

describe Facilities::PPMS::Response do
  let(:provider_locator_body) { JSON.parse(YAML.load_file('spec/support/vcr_cassettes/facilities/va/ppms.yml')['http_interactions'][0]['response']['body']['string'])['value'] }
  let(:response_body) { JSON.parse(YAML.load_file('spec/support/vcr_cassettes/facilities/va/ppms.yml')['http_interactions'][3]['response']['body']['string'])['value'][0] }
  let(:response) { Facilities::PPMS::Response.new(response_body, 200) }
  let(:bbox) { { bbox: [-79, 38, -77, 39] } }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:provider_locator_response) { Facilities::PPMS::Response.from_provider_locator(faraday_response, bbox) }
  let(:mapped_provider_list) { Facilities::PPMS::Response.map_provider_list(provider_locator_body) }

  before do
    allow(faraday_response).to receive(:body) { provider_locator_body }
    allow(faraday_response).to receive(:status).and_return(200)
  end

  describe 'getting data' do
    context 'with a successful response' do
      it 'has the proper response object attributes' do
        expect(response).not_to be(nil)
        expect(response.body).to eq(response_body)
        expect(response.get_body).to eq(response_body)
        expect(response.status).to eq(200)
      end

      it 'has the proper provider locator response' do
        expect(provider_locator_response).not_to be(nil)
        expect(provider_locator_response.count).to eq(1)
        expect(provider_locator_response[0]['Name']).to eq('DOCTOR PARTNERS OF SHENANDOAH VALLEY')
      end

      it 'has the proper mapped provider list' do
        expect(mapped_provider_list).not_to be(nil)
        expect(mapped_provider_list.count).to eq(9)
        expect(mapped_provider_list[0]['Latitude']).to eq(45.5)
      end
    end
  end
end
