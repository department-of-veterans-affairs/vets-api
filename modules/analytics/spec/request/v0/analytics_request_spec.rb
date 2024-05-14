# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Analytics', type: :request do
  before do
    sign_in_as(current_user)
  end

  describe 'GET `index`' do
    let(:current_user) { build(:user, :loa3, icn: '123498767V234859', uuid:'test-guid') }

    it 'returns things' do
      get '/analytics/v0/user/hashes'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ 'user' => { 'fingerprint' => 'e867710d806a3533f0843405c3ba9bdd0769b2ff84fcce8f75e6b64a406e70c3'} })
    end

    
  end
end
