# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DependentsVerificationsController do
  let(:user) { create(:evss_user) }

  before do
    sign_in_as(user)
  end

  describe '#index' do
    context 'with a valid bgs response' do
      it 'returns a list of dependency verifications' do
        VCR.use_cassette('bgs/diaries/read') do
          get(:index)
          expect(response).to have_http_status(:ok)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['type']).to eq('dependency_decs')
        end
      end
    end
  end

  describe 'POST create' do
    context 'logged in loa3 user' do
      it 'validates successfully' do
        form_params = { dependency_verification_claim: { form: { update_diaries: true } } }

        post(:create, params: form_params)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with update set to false' do
      it 'returns no content' do
        post(:create, params: { dependency_verification_claim: { form: { update_diaries: false } } })
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
