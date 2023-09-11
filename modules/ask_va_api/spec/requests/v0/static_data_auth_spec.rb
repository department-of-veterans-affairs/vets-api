# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AskVAApi::V0::StaticDataAuth', type: :request do
  describe 'index' do
    let(:user228) { build(:user, :loa3, { email: 'vets.gov.user+228@gmail.com' }) }
    let(:user056) { build(:user, :loa3, { email: 'vets.gov.user+56@gmail.com' }) }

    context 'when user is not logged in' do
      before do
        get '/ask_va_api/v0/static_data_auth'
      end

      it 'response with status :ok' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when expected user is logged in' do
      before do
        sign_in(user228)
        get '/ask_va_api/v0/static_data_auth'
      end

      it 'response with status :ok' do
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include('Ruchi')
      end
    end

    context 'when unexpected user is logged in' do
      before do
        sign_in(user056)
        get '/ask_va_api/v0/static_data_auth'
      end

      it 'response with status :unauthorized' do
        expect(response).to have_http_status('403')
        expect(response.body).to include('You do not have access to this resource.')
      end
    end
  end
end
