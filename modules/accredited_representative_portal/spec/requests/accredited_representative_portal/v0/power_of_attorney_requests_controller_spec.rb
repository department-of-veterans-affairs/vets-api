# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  before do
    Flipper.enable(:representatives_portal_api)
  end

  describe 'POST /accept' do
    it 'returns a successful response with an accepted message' do
      id = '123'
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{id}/accept"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Accepted')
    end
  end
end
