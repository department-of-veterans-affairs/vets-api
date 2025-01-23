# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Profile::Contacts', type: :request do
  include SchemaMatchers
  let(:user) { build(:user, :loa3, idme_uuid:) }
  let(:resource) { JSON.parse(response.body) }

  around do |ex|
    VCR.use_cassette(cassette) { ex.run }
  end

  describe 'GET /v0/profile/contacts' do
    context '200 response' do
      let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_200' }

      it 'responds with contacts' do
        sign_in_as(user)
        get '/v0/profile/contacts'
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('contacts')
        expect(resource['data'].size).to eq(4)
      end
    end

    context '401 response' do
      let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_200' }

      it 'responds with 401 status' do
        get '/v0/profile/contacts'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context '403 response' do
      let(:user) { build(:user, :loa1) }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_200' }

      it 'responds with 403 status' do
        sign_in_as(user)
        get '/v0/profile/contacts'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '404 response' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_404' }

      it 'responds with 404 status' do
        sign_in_as(user)
        get '/v0/profile/contacts'
        expect(response).to have_http_status(:not_found)
      end
    end

    context '500 response from VA Profile' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_500' }

      it 'responds with 400 status (excluding 5xx response from SLO)' do
        sign_in_as(user)
        get '/v0/profile/contacts'
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
