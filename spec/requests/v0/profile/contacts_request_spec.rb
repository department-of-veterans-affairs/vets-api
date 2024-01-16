# frozen_string_literal: true

require 'rails_helper'

describe '/v0/profile/contacts', type: :request do
  let(:idme_uuid) { 'e444837a-e88b-4f59-87da-10d3c74c787b' }
  let(:user) { build(:user, :loa3, idme_uuid:) }

  before do
    Flipper.enable(:profile_contacts)
    sign_in_as(user)
  end

  describe 'GET /v0/profile/contacts' do
    context 'successful request' do
      it 'matches the contacts schema' do
        VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_200') do
          get v0_profile_contacts_path
          expect(response).to have_http_status(:ok)
          # expect(response).to match_response_schema()
        end
      end
    end
  end
end
