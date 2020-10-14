# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'health_quest questionnaires', type: :request, skip_mvi: true do
  let(:access_denied_message) { 'You do not have access to the health quest service' }

  before do
    sign_in_as(current_user)
  end

  describe 'GET questionnaires' do
    context 'loa1 user' do
      let(:current_user) { build(:user, :loa1) }

      it 'has forbidden status' do
        get '/health_quest/v0/pgd_questionnaires/32'

        expect(response).to have_http_status(:forbidden)
      end

      it 'has access denied message' do
        get '/health_quest/v0/pgd_questionnaires/32'

        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(access_denied_message)
      end
    end

    context 'health quest user' do
      let(:current_user) { build(:user, :health_quest) }

      it 'has success status' do
        get '/health_quest/v0/pgd_questionnaires/32'

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
