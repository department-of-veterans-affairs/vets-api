# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::UserActionEventsController, type: :controller do
  include RequestHelper

  context 'when not logged in' do
    it 'returns unauthorized' do
      get :index
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #index' do
    let(:idme_uuid) { 'some-idme-uuid' }
    let(:user) { create(:user, idme_uuid:) }
    let!(:user_verification) { create(:idme_user_verification, idme_uuid:) }

    before do
      sign_in_as(user)
    end

    context 'when there are user actions' do
      let(:user_action_event) { create(:user_action_event, details: 'Sample event') }
      let(:user_action) do
        create(:user_action, subject_user_verification_id: user_verification.id, user_action_event: user_action_event)
      end
      let(:page) { 1 }
      let(:per_page) { 10 }

      it 'returns a successful response' do
        get :index, params: { start_date: 1.month.ago.to_date, end_date: Time.zone.today }
        expect(response).to have_http_status(:success)
      end
    end
  end
end
