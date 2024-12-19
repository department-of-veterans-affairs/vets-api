# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:unauthorized_user) { create(:representative_user) }
  let(:poa_request_details_id) { '123' }
  let(:poa_request_details_mock_data) do
    {
      'status' => 'Pending',
      'declinedReason' => nil,
      'powerOfAttorneyCode' => '091',
      'submittedAt' => '2024-04-30T11:03:17Z',
      'acceptedOrDeclinedAt' => nil,
      'isAddressChangingAuthorized' => false,
      'isTreatmentDisclosureAuthorized' => true,
      'veteran' => { 'firstName' => 'Jon', 'middleName' => nil, 'lastName' => 'Smith',
                     'participantId' => '6666666666666' },
      'representative' => { 'email' => 'j2@example.com', 'firstName' => 'Jane', 'lastName' => 'Doe' },
      'claimant' => { 'firstName' => 'Sam', 'lastName' => 'Smith', 'participantId' => '777777777777777',
                      'relationshipToVeteran' => 'Child' },
      'claimantAddress' => { 'city' => 'Hartford', 'state' => 'CT', 'zip' => '06107', 'country' => 'GU',
                             'militaryPostOffice' => nil, 'militaryPostalCode' => nil }
    }
  end
  let(:poa_request_list_mock_data) do
    [poa_request_details_mock_data, poa_request_details_mock_data, poa_request_details_mock_data]
  end

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    allow(Settings.accredited_representative_portal).to receive(:pilot_user_email_poa_codes)
      .and_return({ test_user.email => ['091'] })
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    context 'when user is authorized' do
      before { login_as(test_user) }

      it 'returns the list of power of attorney requests' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(poa_request_list_mock_data)
      end
    end

    context 'when user is not authorized' do
      before { login_as(unauthorized_user) }

      it 'returns forbidden error' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to eq(
          { 'errors' => ['User is not authorized to perform the requested action'] }
        )
      end
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    context 'when user is authorized' do
      before { login_as(test_user) }

      it 'returns the details of a power of attorney request' do
        get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request_details_id}")
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(poa_request_details_mock_data)
      end
    end

    context 'when user is not authorized' do
      before { login_as(unauthorized_user) }

      it 'returns forbidden error' do
        get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request_details_id}")
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to eq(
          { 'errors' => ['User is not authorized to perform the requested action'] }
        )
      end
    end
  end
end
