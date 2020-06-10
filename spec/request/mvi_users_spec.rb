# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::MviUsersController, type: :request do

  describe 'PUT #update' do
    form_id = '21-686C' # a form id that is _invalid_ for this endpoint

    it 'returns 403 for invalid (form) id parameter' do
      put "/v0/mvi_users/#{form_id}"
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq("Action is prohibited with id parameter #{form_id}")
    end

    context('when (form) id parameter is valid') do
      form_id = '21-526EZ' # a form id that is _valid_ for this endpoint


      context('when user is missing birls_id and participant_id') do
        let(:user) { build(:user_with_no_ids) }
        before do
          sign_in_as(user)
        end

        it 'returns 200 and calls proxy add' do
          put "/v0/mvi_users/#{form_id}"
          expect(response).to have_http_status(:ok)
          # also, expect proxy add call to evss
        end
      end

      context('when user is missing birls_id only') do
        let(:user) { build(:user_with_no_birls_id) }
        before do
          sign_in_as(user)
        end

        it 'returns 500' do
          put "/v0/mvi_users/#{form_id}"
          expect(response).to have_http_status(:internal_server_error)
        end
      end

      context('when user has partipant_id and birls_id') do
        let(:user) { build(:user, :loa3) }
        before do
          sign_in_as(user)
        end

        it 'returns _ ?, and does _not_ call proxy add' do
          # put "/v0/mvi_users/#{form_id}"
          # returns 200?
          # is there a code for "you tried to do something and we did nothing but it's still cool"?
          # also, expect not to call evss
        end
      end
    end
  end
end

