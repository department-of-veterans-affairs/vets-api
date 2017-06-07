# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::LettersController, type: :controller do
  include SchemaMatchers

  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:session) { Session.create(uuid: user.uuid) }

  context 'with a mocked letters response' do
    let(:mock_response) { YAML.load_file(Rails.root.join('config', 'evss', 'mock_letters_response.yml.example')) }
    before { allow_any_instance_of(EVSS::Letters::MockService).to receive(:mocked_response).and_return(mock_response) }
    it 'should have a response that matches the schema' do
      request.headers['Authorization'] = "Token token=#{session.token}"
      get :index
      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('letters')
    end
  end
end
