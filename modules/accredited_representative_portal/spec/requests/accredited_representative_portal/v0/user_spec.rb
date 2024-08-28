# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/authentication'

RSpec.describe 'AccreditedRepresentativePortal::V0::User', type: :request do
  describe '#show' do
    context 'when authenticated' do
      let(:arp_client_id) { 'arp' }
      let(:current_representative_user) { create(:representative_user) }

      before do
        login_as(current_representative_user)
      end

      it 'responds with the current_user' do
        get '/accredited_representative_portal/v0/user'

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['uuid']).to eq(current_representative_user.uuid)
      end
    end

    context 'when not authenticated' do
      it 'responds with unauthorized' do
        get '/accredited_representative_portal/v0/user'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
