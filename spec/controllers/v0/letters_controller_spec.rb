# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::LettersController, type: :controller do
  include SchemaMatchers

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:session) { Session.create(uuid: user.uuid) }

  context 'with a mocked letters response' do
    let(:mock_response) do
      YAML.load_file(Rails.root.join('spec', 'support', 'evss', 'mock_letters_response.yml'))
    end

    before do
      Settings.evss.mock_letters = true
      allow_any_instance_of(EVSS::Letters::MockService).to receive(:mocked_response)
        .and_return(mock_response[user.ssn])
    end

    it 'should have a response that matches the schema' do
      request.headers['Authorization'] = "Token token=#{session.token}"
      get :index
      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('letters')
    end
  end
end
