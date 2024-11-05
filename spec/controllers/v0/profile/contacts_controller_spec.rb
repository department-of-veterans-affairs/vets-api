# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::ContactsController, type: :controller do
  include SchemaMatchers

  let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
  let(:user) { build(:user, :loa3, idme_uuid:) }
  let(:loa1_user) { build(:user, :loa1) }
  let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_200' }

  describe 'GET /v0/profile/contacts' do
    subject { get :index }

    around do |ex|
      VCR.use_cassette(cassette) { ex.run }
    end

    context 'successful request' do
      it 'returns emergency contacts' do
        sign_in_as user
        expect(subject).to have_http_status(:success)
        expect(response).to match_response_schema('contacts')
      end
    end

    context 'user is not authenticated' do
      it 'returns an unauthorized status code' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'user is loa1' do
      it 'returns a forbidden status code' do
        sign_in_as loa1_user
        expect(subject).to have_http_status(:forbidden)
      end
    end

    context '500 Internal Server Error from VA Profile Service' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_500' }

      it 'returns a bad request status code' do
        sign_in_as user
        expect(subject).to have_http_status(:bad_request)
      end
    end

    context '504 Gateway Timeout from VA Profile Service' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_500' }

      it 'returns a gateway timeout status code' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        sign_in_as user
        expect(subject).to have_http_status(:gateway_timeout)
      end
    end
  end
end
