# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VeteranStatusController', type: :request do
  it 'returns a temporary dummy response' do
    post '/services/veteran_confirmation/v0/status'
    expect(response).to have_http_status(:ok)
    expect(response.body).to be_a(String)
    expect(JSON.parse(response.body)['hit_it']).to eq('yep')
  end
end
