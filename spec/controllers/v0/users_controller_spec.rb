# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::UsersController, type: :controller do
  include RequestHelper

  context 'when not logged in' do
    it 'returns unauthorized' do
      get :show
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when logged in as an LOA1 user' do
    let(:user) { build(:user, :loa1) }

    before do
      sign_in_as(user)
      create(:in_progress_form, user_uuid: user.uuid, form_id: 'edu-1990')
    end

    it 'returns a JSON user profile' do
      get :show
      json = json_body_for(response)
      expect(response).to be_successful
      expect(json['attributes']['profile']['email']).to eq(user.email)
    end
  end

  context 'when logged in as a vet360 user' do
    let(:user) { build(:vets360_user) }

    before do
      sign_in_as(user)
    end

    it 'returns a JSON user profile with a bad_address' do
      get :show
      json = json_body_for(response)

      mailing_address = json.dig('attributes', 'vet360_contact_information', 'mailing_address')

      expect(response).to be_successful
      expect(mailing_address.key?('bad_address')).to be(true)
    end
  end
end
