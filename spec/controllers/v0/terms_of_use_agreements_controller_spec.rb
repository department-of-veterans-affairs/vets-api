# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::TermsOfUseAgreementsController, type: :controller do
  let(:user) { create(:user) }
  let(:user_account) { create(:user_account) }
  let(:agreement_version) { 'v1' }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(user).to receive(:user_account).and_return(user_account)
    sign_in(user)
  end

  describe 'GET #latest' do
    let(:expected_status) { :ok }

    it 'returns ok status' do
      get :latest, params: { version: agreement_version }

      expect(response).to have_http_status(expected_status)
    end

    context 'when a terms of use agreement exists for the authenticated user' do
      let!(:terms_of_use_acceptance) do
        create(:terms_of_use_agreement, user_account:, response: terms_response, agreement_version:)
      end
      let(:terms_response) { 'accepted' }

      it 'returns the latest terms of use agreement for the authenticated user' do
        get :latest, params: { version: agreement_version }
        expect(JSON.parse(response.body)['terms_of_use_agreement']['response']).to eq(terms_response)
        expect(JSON.parse(response.body)['terms_of_use_agreement']['agreement_version']).to eq(agreement_version)
      end
    end

    context 'when a terms of use agreement does not exist for the authenticated user' do
      it 'returns nil terms of use agreement' do
        get :latest, params: { version: agreement_version }
        expect(JSON.parse(response.body)['terms_of_use_agreement']).to eq(nil)
      end
    end
  end

  describe 'POST #accept' do
    context 'when the agreement is accepted successfully' do
      before do
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
      end

      it 'returns the accepted terms of use agreement' do
        post :accept, params: { version: agreement_version }

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['terms_of_use_agreement']['response']).to eq('accepted')
        expect(StatsD).to have_received(:increment).with(
          'api.terms_of_use_agreements.accepted',
          tags: ["version:#{agreement_version}"]
        )
        expect(Rails.logger).to have_received(:info).with(
          '[TermsOfUseAgreement] [Accepted]',
          hash_including(:terms_of_use_agreement_id, :user_account_uuid, :icn, :agreement_version, :response)
        )
      end
    end

    context 'when the agreement acceptance fails' do
      before do
        allow_any_instance_of(TermsOfUseAgreement).to receive(:accepted!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'returns an unprocessable_entity' do
        post :accept, params: { version: agreement_version }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST #decline' do
    context 'when the agreement is declined successfully' do
      before do
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
      end

      it 'returns the declined terms of use agreement' do
        post :decline, params: { version: agreement_version }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['terms_of_use_agreement']['response']).to eq('declined')
        expect(StatsD).to have_received(:increment).with(
          'api.terms_of_use_agreements.declined',
          tags: ["version:#{agreement_version}"]
        )
        expect(Rails.logger).to have_received(:info).with(
          '[TermsOfUseAgreement] [Declined]',
          hash_including(:terms_of_use_agreement_id, :user_account_uuid, :icn, :agreement_version, :response)
        )
      end
    end

    context 'when the agreement declination fails' do
      before do
        allow_any_instance_of(TermsOfUseAgreement).to receive(:declined!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'returns an error unprocessable_entity' do
        post :decline, params: { version: agreement_version }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
