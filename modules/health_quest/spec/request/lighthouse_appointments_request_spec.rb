# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lighthouse appointments', type: :request do
  let(:access_denied_message) { 'You do not have access to the health quest service' }
  let(:questionnaire_responses_id) { '32' }

  describe 'GET appointment `show`' do
    context 'loa1 user' do
      before do
        sign_in_as(current_user)
      end

      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        get '/health_quest/v0/lighthouse_appointments/I2-ABC123'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/lighthouse_appointments/I2-ABC123'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }

      before do
        sign_in_as(current_user)
      end

      it 'returns an empty appointment' do
        get '/health_quest/v0/lighthouse_appointments/I2-ABC123'

        expect(JSON.parse(response.body)).to eq({})
      end
    end
  end

  describe 'GET appointments `index`' do
    context 'loa1 user' do
      let(:current_user) { build(:user, :loa1) }

      before do
        sign_in_as(current_user)
      end

      it 'has forbidden status' do
        get '/health_quest/v0/lighthouse_appointments?test=1234'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/lighthouse_appointments?test=1234'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }

      before do
        sign_in_as(current_user)
      end

      it 'returns an empty appointment list' do
        get '/health_quest/v0/lighthouse_appointments?test=1234'

        expect(JSON.parse(response.body)).to eq({ 'data' => [] })
      end
    end
  end
end
