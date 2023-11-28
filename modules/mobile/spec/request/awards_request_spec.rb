# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe Mobile::V0::AwardsController, type: :request do
  include JsonSchemaMatchers

  before do
    sis_user(participant_id: 600061742)
  end

  describe 'GET /mobile/v0/awards' do
    it 'responds to GET #index' do
      VCR.use_cassette('bgs/awards_service/get_awards') do
        VCR.use_cassette('bid/awards/get_awards_pension') do
          get '/mobile/v0/awards', headers: sis_headers
        end
      end

      binding.pry

      # expect(response).to be_successful
      # expect(response.parsed_body['data'][0, 2]).to eq(
      #                                                 [{ 'id' => '915',
      #                                                    'type' => 'cemetery',
      #                                                    'attributes' => { 'name' => 'ABRAHAM LINCOLN NATIONAL CEMETERY',
      #                                                                      'type' => 'N' } },
      #                                                  { 'id' => '400',
      #                                                    'type' => 'cemetery',
      #                                                    'attributes' => { 'name' => 'ALABAMA STATE VETERANS MEMORIAL CEMETERY',
      #                                                                      'type' => 'S' } }]
      #                                               )
      # expect(response.body).to match_json_schema('cemetery', strict: true)
    end
  end
end
