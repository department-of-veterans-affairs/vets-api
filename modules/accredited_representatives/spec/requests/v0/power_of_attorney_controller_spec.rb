# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentatives::V0::PowerOfAttorneyController, type: :request do
  include RequestHelper

  before do
    Flipper.enable(:representatives_portal_api)
  end

  describe 'POST /accept' do
    it 'returns a successful response with an accepted message' do
      post '/accredited_representatives/v0/power_of_attorney/accept'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Accepted')
    end
  end
end
