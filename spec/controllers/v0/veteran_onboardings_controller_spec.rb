# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VeteranOnboardingsController, type: :controller do
  let(:user) { create(:user, :loa3) }
  let(:veteran_onboarding) do
    user_verification = create(:user_verification, idme_uuid: user.identity.idme_uuid)
    create(:veteran_onboarding, user_account: user_verification.user_account)
  end

  before do
    Flipper.enable(:veteran_onboarding_beta_flow, user)
    sign_in_as(user)
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: veteran_onboarding.to_param }
      expect(response).to be_successful
    end
  end

  describe 'PATCH #update' do
    let(:new_attributes) do
      { display_onboarding_flow: true }
    end

    it 'updates the requested veteran_onboarding' do
      patch :update, params: { id: veteran_onboarding.to_param, veteran_onboarding: new_attributes }
      veteran_onboarding.reload
      expect(veteran_onboarding.display_onboarding_flow).to eq(true)
    end

    it 'renders a successful response' do
      patch :update, params: { id: veteran_onboarding.to_param, veteran_onboarding: new_attributes }
      expect(response).to be_successful
    end
  end
end
