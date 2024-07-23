# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::ContactsController, type: :controller do
  include SchemaMatchers

  let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
  let(:user) { build(:user, :loa3, idme_uuid:) }
  let(:loa1_user) { build(:user, :loa1) }

  describe 'GET /v0/profile/contacts' do
    subject { get :index }

    around do |ex|
      VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_200') do
        ex.run
      end
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
  end
end
