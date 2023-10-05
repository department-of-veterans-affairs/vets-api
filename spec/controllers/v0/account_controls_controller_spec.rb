# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::AccountControlsController, type: :controller do
  let(:service_account_access_token) { build(:service_account_access_token) }
  let(:user_account) { create(:user_account, icn:) }
  let(:user_verification) { create(:logingov_user_verification, user_account:) }
  let(:icn) { SecureRandom.hex }
  let(:csp_uuid) { user_verification.logingov_uuid }
  let(:account_controls_params) { { type: type_param, icn: icn_param, csp_uuid: csp_uuid_param } }
  let(:type_param) { 'logingov' }
  let(:icn_param) { icn }
  let(:csp_uuid_param) { csp_uuid }

  subject { V0::AccountControlsController.new } 

  before do
    allow_any_instance_of(V0::AccountControlsController).to receive(:authenticate_service_account).and_return(true)
    subject.instance_variable_set(:@service_account_access_token, service_account_access_token)
  end
  
  describe 'POST #csp_lock' do
    context 'when a request is made with an ICN' do
      let(:csp_uuid_param) { nil }

      context 'when a UserVerification matches the requested ICN' do
        it 'locks the user account' do
          post :csp_lock, params: account_controls_params

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when a UserVerification does not match the requested ICN' do
        let(:icn_param) { 'some-icn' }

        it 'returns a not found error' do
          post :csp_lock, params: account_controls_params

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when a request is made with a CSP uuid' do
      context 'when a UserVerification matches the requested CSP uuid' do
        it 'locks the user account' do
          post :csp_lock, params: account_controls_params

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when a UserVerification does not match the requested CSP uuid' do
        let(:csp_uuid_param) { 'some-csp-uuid' }

        it 'returns a not found error' do
          post :csp_lock, params: account_controls_params

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  # describe 'POST csp_unlock' do

  # end
end
