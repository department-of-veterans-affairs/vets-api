# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'health_quest questionnaire responses', type: :request do
  include SchemaMatchers

  before do
    # Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    # allow_any_instance_of(HealthQuest::PGDService).to receive(:session).and_return('stubbed_token')
  end

  context 'loa1 user' do
    let(:current_user) { build(:user, :loa1) }

    describe 'GET questionnaires' do
      it 'does not have access' do
        get '/health_quest/v0/pgd_ques_responses/32'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end
  end

  context 'health quest user' do
    let(:current_user) { build(:user, :health_quest) }

    describe 'GET questionnaires' do
      it 'has access to questionnaires have access' do
        get '/health_quest/v0/pgd_ques_responses/32'
        expect(response).to have_http_status(:ok)
        result = JSON.parse(response.body)
        expect(result['data']['attributes']['text']).to eq('this is the questionnaire_response')
      end
    end
  end
end
