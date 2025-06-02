# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/veterans_health/client'
require 'lighthouse/veterans_health/models/immunization'
require 'lighthouse/veterans_health/serializers/immunization_serializer'

RSpec.describe 'MyHealth::V2::ImmunizationsController', :skip_json_api_validation, type: :request do
  let(:default_params) { { start_date: '2015-01-01', end_date: '2015-12-31' } }
  let(:path) { '/my_health/v2/medical_records/immunizations' }
  let(:immunizations_cassette) { 'lighthouse/veterans_health/get_immunizations' }
  let(:current_user) { build(:user, :mhv) }
  

  before do
    sign_in_as(current_user)
  end

  describe 'GET /my_health/v2/medical_records/immunizations' do
    context 'happy path' do
      before do          
        VCR.use_cassette(immunizations_cassette) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end
   
    end
  end
end
