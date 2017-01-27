# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'forms', type: :request do
  let(:token) { 'abracadabra-open-sesame' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:loa3_user) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET' do
    context 'when a form is found' do
      let!(:serialized_form) { FactoryGirl.create(:serialized_form, user_uuid: user.uuid) }

      it 'returns the form as JSON' do
        get v0_form_url(serialized_form.form_id), nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(serialized_form.form_data)
      end
    end

    context 'when a form is not found' do
      it 'responds with a 404' do
        get v0_form_url(99), nil, auth_header
        expect(response).to have_http_status(:not_found)
      end
    end
  end

end
