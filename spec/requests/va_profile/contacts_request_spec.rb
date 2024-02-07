# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'contacts' do
  include SchemaMatchers
  let(:user) { build(:user, :loa3, idme_uuid:) }
  let(:body) { JSON.parse(response.body) }

  describe 'GET /v0/profile/contacts -> 200' do
    let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }

    it 'responds with contacts' do
      sign_in_as(user)
      VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_200') do
        get '/v0/profile/contacts'
      end
      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('contacts')
      expect(body['contacts'].size).to eq(4)
    end
  end

  describe 'GET /v0/profile/contacts -> 404' do
    let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }

    it 'responds with messages' do
      sign_in_as(user)
      VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_404') do
        get '/v0/profile/contacts'
      end
      expect(response).to have_http_status(:not_found)
      expect(response).to match_response_schema('contacts')
      expect(body['messages'].size).to eq(1)
    end
  end
end
