# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AskVAApi::V0::StaticDataAuth', type: :request do
  describe 'index' do
    let(:user) { build(:user, :loa3) }

    context 'when user is logged in' do
      before do
        sign_in(user)
        get '/ask_va_api/v0/static_data_auth'
      end

      it 'response with status :ok' do
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include('Ruchi')
      end
    end

    context 'when user is not logged in' do
      before do
        get '/ask_va_api/v0/static_data_auth'
      end

      it 'response with status :ok' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
