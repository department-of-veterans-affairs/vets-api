# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::FormsController, type: :controller do
  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:session) { Session.create(uuid: user.uuid) }

  before {
    request.headers['Authorization'] = "Token token=#{session.token}"
  }
  describe 'GET' do
    context 'with an id points to a form' do
      it 'returns the form as JSON' do
        get :show, id: 1
        puts response
        expect(response).to have_http_status(200)
      end
    end

    context 'with an id that does not point to a form' do
      it 'returns record not found' do
        get :show, id: 99
        puts response
        expect(response).to have_http_status(404)
      end
    end
  end
end
