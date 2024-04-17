# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/authentication'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:representative_user) { create(:representative_user) }

  before do
    login_as(representative_user)
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

  describe 'POST /decline' do
    it 'returns a successful response with an accepted message' do
      id = '123'
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{id}/decline"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Declined')
    end
  end
end
