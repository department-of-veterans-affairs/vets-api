# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'dependents', type: :request do
  let!(:user) { sis_user }

  describe '#show' do
    it 'shows a list of dependents' do
      VCR.use_cassette('bgs/claimant_web_service/dependents') do
        get('/mobile/v0/dependents', params: { id: user.participant_id }, headers: sis_headers)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['type']).to eq('dependents')
      end
    end

    context 'with an erroneous bgs response' do
      it 'returns no content' do
        allow_any_instance_of(BGS::DependentService).to receive(:get_dependents).and_raise(BGS::ShareError)
        get('/mobile/v0/dependents', params: { id: user.participant_id }, headers: sis_headers)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
