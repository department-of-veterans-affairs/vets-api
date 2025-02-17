# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let!(:poa_code) { 'x23' }
  let!(:other_poa_code) { 'z99' }

  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859')
  end

  let!(:accredited_individual) do
    create(:user_account_accredited_individual,
           user_account_email: test_user.email,
           user_account_icn: test_user.icn,
           poa_code: poa_code)
  end

  let!(:representative) do
    create(:representative,
           :vso,
           representative_id: accredited_individual.accredited_individual_registration_number,
           poa_codes: [poa_code])
  end

  let!(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
  let!(:other_vso) { create(:organization, poa: other_poa_code, can_accept_digital_poa_requests: true) }

  let!(:poa_request) { create(:power_of_attorney_request, poa_code: poa_code) }
  let!(:other_poa_request) { create(:power_of_attorney_request, poa_code: other_poa_code) }

  let(:time) { '2024-12-21T04:45:37.000Z' }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
    travel_to(time)
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    context 'when user belongs to a digital-POA-request-accepting VSO' do
      it 'allows access and returns the list of POA requests scoped to the user' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        expect(parsed_response.size).to eq(1)
        expect(parsed_response.first['id']).to eq(poa_request.id)
        expect(parsed_response.map { |p| p['id'] }).not_to include(other_poa_request.id)
      end
    end

    context 'when user has no associated VSOs' do
      before do
        representative.destroy!
      end

      it 'returns 403 Forbidden' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user has a VSO but no POA requests' do
      before do
        poa_request.power_of_attorney_form.destroy!
        poa_request.destroy!
      end

      it 'returns an empty collection' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq([])
      end
    end

    context 'when user’s VSO does not accept digital POAs' do
      before do
        vso.update!(can_accept_digital_poa_requests: false)
      end

      it 'returns 403 Forbidden' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests')

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    context 'when user is authorized' do
      it 'returns the details of the POA request' do
        get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

        expect(response).to have_http_status(:ok)
        expect(parsed_response['id']).to eq(poa_request.id)
      end
    end

    context 'when user is unauthorized (trying to access another VSO’s POA request)' do
      it 'returns 403 Forbidden' do
        get("/accredited_representative_portal/v0/power_of_attorney_requests/#{other_poa_request.id}")

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user’s VSO does not accept digital POAs' do
      before do
        vso.update!(can_accept_digital_poa_requests: false)
      end

      it 'returns 403 Forbidden' do
        get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when POA request does not exist' do
      it 'returns 404 Not Found' do
        get('/accredited_representative_portal/v0/power_of_attorney_requests/nonexistent')

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
