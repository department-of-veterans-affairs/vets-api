# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user, email: 'test@va.gov') }
  let(:poa_request_details_id) { '12346' }
  let(:poa_request_details_mock_data) do
    AccreditedRepresentativePortal::PENDING_POA_REQUEST_MOCK_DATA
  end

  let(:poa_request_list_mock_data) do
    AccreditedRepresentativePortal::POA_REQUEST_LIST_MOCK_DATA
  end

  before do
    allow_any_instance_of(
      AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy
    ).to receive(:pilot_user_email_poa_codes)
      .and_return({ 'test@va.gov' => ['091'] })
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    it 'returns the list of a power of attorney request' do
      get('/accredited_representative_portal/v0/power_of_attorney_requests')
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to eq(poa_request_list_mock_data.as_json)
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    it 'returns the details of a power of attorney request' do
      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request_details_id}")
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to include(poa_request_details_mock_data.as_json)
    end
  end
end
