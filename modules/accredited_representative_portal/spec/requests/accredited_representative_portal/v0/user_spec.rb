# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/authentication'

RSpec.describe 'AccreditedRepresentativePortal::V0::User', type: :request do
  describe '#show' do
    context 'when authenticated' do
      let(:arp_client_id) { 'arp' }
      let(:current_representative_user) { create(:representative_user) }
      let!(:in_progress_form) do
        create(
          :in_progress_form,
          user_uuid: current_representative_user.uuid,
          status: 'pending'
        )
      end

      before do
        login_as(current_representative_user)
      end

      it 'responds with the current_user' do
        get '/accredited_representative_portal/v0/user'

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body['account']['account_uuid']).to eq(current_representative_user.uuid)
        expect(response_body['profile']).to eq(
          {
            'first_name' => current_representative_user.first_name,
            'last_name' => current_representative_user.last_name,
            'verified' => true
          }
        )
        expect(response_body['in_progress_forms'][0]['form']).to eq(in_progress_form.form_id)
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
