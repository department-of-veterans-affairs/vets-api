# frozen_string_literal: true

require 'rails_helper'
require_relative '../rails_helper'

RSpec.describe Mobile::ApplicationController, type: :controller do
  controller do
    def index
      head :ok
    end
  end

  describe 'authentication' do
    let(:error_detail) { JSON.parse(response.body)['errors'].first['detail'] }

    context 'wwhen the Authentication header is missing' do
      it 'returns forbidden' do
        get :index

        expect(response).to have_http_status(:forbidden)
        expect(error_detail).to eq('Missing Authorization header')
      end
    end

    context 'wwhen the Authentication header is blank' do
      it 'returns forbidden' do
        request.headers['Authorization'] = ''
        get :index

        expect(response).to have_http_status(:forbidden)
        expect(error_detail).to eq('Authorization header Bearer token is blank')
      end
    end

    context 'with a user who has an inactive iam session' do
      it 'returns forbidden' do
        VCR.use_cassette('iam_ssoe_oauth/introspect_inactive') do
          request.headers['Authorization'] = "Bearer #{access_token}"
          get :index
        end

        expect(response).to have_http_status(:forbidden)
        expect(error_detail).to eq('IAM user session is inactive')
      end
    end

    context 'with a user who has an active iam session' do
      it 'returns ok' do
        VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
          request.headers['Authorization'] = "Bearer #{access_token}"
          get :index
        end

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with a user who has a cached iam session' do
      before { sign_in }

      it 'returns returns ok without hitting the introspect endpoint' do
        request.headers['Authorization'] = "Bearer #{access_token}"
        get :index

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
