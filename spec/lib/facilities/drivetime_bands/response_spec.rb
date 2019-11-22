# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/response'

describe Facilities::DrivetimeBands::Response do
  let(:response_body) do
    YAML.load_file(
      'spec/support/vcr_cassettes/facilities/va/vha_648A4.yml'
    )['http_interactions'][0]['response']['body']['string']
  end

  let(:response) { Facilities::DrivetimeBands::Response.new(response_body) }
  let(:get_features) { response.get_features }

  describe 'getting data' do
    context 'with a successful response' do
      it 'has the proper response object attributes' do
        expect(response).not_to be(nil)
        expect(response.body).to eq(response_body)
      end

      it 'has the proper features' do
        expect(get_features).not_to be(nil)
      end
    end
  end
end
