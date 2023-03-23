# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::MHVOptInFlagsController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :show, params: { feature: 'secure_messaging' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when logged in' do
    let(:user_verification) { create(:user_verification) }
    let(:user_account) { user_verification.user_account }
    let(:account_uuid) { user_account.id }
    let(:user) { create(:user, account_uuid:) }
    let(:feature) { 'secure_messaging' }

    before do
      allow(UserVerification).to receive(:find_by).and_return(user_verification)
      sign_in_as(user)
    end

    shared_examples 'returned mhv_opt_in_flag attributes response' do
      let(:opt_in_flag_attributes) { JSON.parse(response.body)['mhv_opt_in_flag'] }

      it 'returns the user_account_id' do
        expect(opt_in_flag_attributes['user_account_id']).to eq(account_uuid)
      end

      it 'returns the feature flag' do
        expect(opt_in_flag_attributes['feature']).to eq(feature)
      end
    end

    describe '#show' do
      before do
        MHVOptInFlag.create(user_account_id: user.account_uuid, feature:)
        get :show, params: { feature: }
      end

      context 'no opt in flag record is found' do
        let(:feature) { 'invalid_feature_value' }

        it 'returns a 404 status' do
          expect(JSON.parse(response.body)['errors']).to include('Record not found')
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'opt in flag record is found' do
        it 'returns ok status' do
          expect(response).to have_http_status(:ok)
        end

        it_behaves_like 'returned mhv_opt_in_flag attributes response'
      end
    end

    describe '#create' do
      context 'unknown error' do
        before { allow(MHVOptInFlag).to receive(:find_or_create_by).and_raise('Internal Server Error') }

        it 'returns an unknown error response' do
          post :create, params: { feature: }

          expect(response).to have_http_status(:internal_server_error)
          expect(JSON.parse(response.body)['errors']).to include('Internal Server Error')
        end
      end

      context 'validation' do
        let(:feature) { 'invalid_feature_value' }

        it 'returns a bad_request error for feature param not included in MHVOptInFlag::FEATURES' do
          post :create, params: { feature: }

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors']).to include('Feature param is not valid')
        end
      end

      context 'requested opt in flag does not exist' do
        before { post :create, params: { feature: } }

        it 'creates a new opt in flag record' do
          expect(response).to have_http_status(:created)
        end

        it_behaves_like 'returned mhv_opt_in_flag attributes response'
      end

      context 'requested opt in flag exists' do
        before do
          MHVOptInFlag.create(user_account_id: user.account_uuid, feature:)
          post :create, params: { feature: }
        end

        it 'finds and returns the existing opt in flag record' do
          expect(response).to have_http_status(:ok)
        end

        it_behaves_like 'returned mhv_opt_in_flag attributes response'
      end
    end
  end
end
