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
          tags: ["agreement_version:#{agreement_version}"]
        )
        expect(Rails.logger).to have_received(:info).with(
          '[TermsOfUseAgreementsController] [accepted]',
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
          tags: ["agreement_version:#{agreement_version}"]
        )
        expect(Rails.logger).to have_received(:info).with(
          '[TermsOfUseAgreementsController] [declined]',
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
