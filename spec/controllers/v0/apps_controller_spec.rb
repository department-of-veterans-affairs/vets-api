# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::AppsController, type: :controller do
  describe '#index and #show' do
    context 'without query param' do
      it 'returns apps' do
        VCR.use_cassette('apps/200_all_apps', match_requests_on: %i[method path]) do
          get :index, params: nil
          expect(response.body).not_to be_empty
        end
      end
    end

    context 'with query param' do
      it 'returns a single app' do
        VCR.use_cassette('apps/200_app_query', match_requests_on: %i[method path]) do
          get :show, params: { id: 'iBlueButton' }
          expect(response.body).not_to be_empty
        end
      end
    end
  end

  describe '#scopes' do
    context 'with a category passed' do
      it 'returns a response' do
        VCR.use_cassette('apps/200_scopes_query', match_requests_on: %i[method path]) do
          get :scopes, params: { category: 'health' }
          expect(response.body).not_to be_empty
        end
      end
    end

    context 'when a category is not passed' do
      it 'returns a 204' do
        VCR.use_cassette('apps/204_scopes_query', match_requests_on: %i[method path]) do
          get :scopes, params: { category: nil }
          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
