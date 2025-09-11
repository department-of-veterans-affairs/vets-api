# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::V0::ClaimsController do
  routes { DependentsBenefits::Engine.routes }

  let(:user) { create(:evss_user) }
  let(:test_form) { build(:dependents_claim).parsed_form }

  before do
    sign_in_as(user)
    allow(Flipper).to receive(:enabled?).with(:dependents_module_enabled, instance_of(User)).and_return(true)
  end

  describe '#show' do
    context 'with a valid bgs response' do
      it 'returns a list of dependents' do
        VCR.use_cassette('bgs/claimant_web_service/dependents') do
          get(:show, params: { id: user.participant_id }, as: :json)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['type']).to eq('dependents')
        end
      end
    end

    context 'with an erroneous bgs response' do
      it 'returns no content' do
        allow_any_instance_of(BGS::DependentService).to receive(:get_dependents).and_raise(BGS::ShareError)
        get(:show, params: { id: user.participant_id }, as: :json)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with flipper disabled' do
      before do
        expect(Flipper).to receive(:enabled?).with(:dependents_module_enabled, instance_of(User)).and_return(false)
      end

      it 'returns forbidden error' do
        get(:show, params: { id: user.participant_id }, as: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST create' do
    context 'with valid params and flipper enabled' do
      it 'validates successfully' do
        post(:create, params: test_form, as: :json)
        expect(response).to have_http_status(:ok)
      end

      it 'creates a saved claim' do
        expect do
          post(:create, params: test_form, as: :json)
        end.to change(DependentsBenefits::SavedClaim, :count).by(1)
      end

      it 'logs the success' do
        expect(Rails.logger).to receive(:info).with(
          match(/DependentsBenefits::SavedClaim Skipping tracking PDF overflow/), instance_of(Hash)
        ).at_least(:once)
        expect(Rails.logger).to receive(:info).with(match(/Successfully created claim/),
                                                    include({ statsd: 'api.dependents_application.create_success' }))
        post(:create, params: test_form, as: :json)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) { { dependents_application: {} } }

      it 'returns validation errors' do
        post(:create, params: invalid_params, as: :json)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create a saved claim' do
        expect do
          post(:create, params: invalid_params, as: :json)
        end.not_to change(DependentsBenefits::SavedClaim, :count)
      end
    end

    context 'with flipper disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:dependents_module_enabled, instance_of(User)).and_return(false)
      end

      it 'returns forbidden error' do
        post(:create, params: test_form, as: :json)
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not create a saved claim' do
        expect do
          post(:create, params: test_form, as: :json)
        end.not_to change(DependentsBenefits::SavedClaim, :count)
      end
    end
  end
end
