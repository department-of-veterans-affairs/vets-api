# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::MviUsersController, type: :request do

  describe 'PUT #update' do

    it 'returns 403 for invalid (form) id parameter' do
      put '/v0/mvi_users/21-686C'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('Action is prohibited with id parameter 21-686C')
    end

    context('with valid (form) id parameter') do

      # We need a test user so we can test mvi proxy add call
      let(:loa3_user) { build(:user, :loa3) }
      before do
        sign_in_as(loa3_user)
      end

      it 'calls proxy add when user is missing participant_id' do
        # returns 200, calls evss
      end

      it 'returns error when user has participant_id and is missing birls_id' do
        # expect(response).to have_http_status(:internal_server_error)
      end

      it 'does nothing when user has partipant_id and birls_id' do
        # returns 200?
        # is there a code for "you tried to do something and we did nothing but it's still cool"?
      end
    end
  end
end

