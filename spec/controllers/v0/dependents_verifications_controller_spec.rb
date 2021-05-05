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
          expect(response.code).to eq('200')
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['type']).to eq('dependency_decs')
        end
      end
    end
  end

  describe 'POST create' do
    it 'fires the #update_diaries call' do
      depenency_verification_service = double('dep_verification')

      expect(depenency_verification_service).to receive(:update_diaries)
      expect(BGS::DependencyVerificationService).to receive(:new) { depenency_verification_service }

      post(:create, params: { update_diaries: true })
    end
  end
end
