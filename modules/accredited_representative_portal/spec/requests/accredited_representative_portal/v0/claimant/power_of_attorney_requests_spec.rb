# frozen_string_literal: true

require_relative '../../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  before do
    login_as(test_user)
    travel_to(time)
  end

  let!(:poa_code) { 'x23' }
  let!(:other_poa_code) { 'z99' }

  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859')
  end

  let!(:accredited_individual) do
    create(:user_account_accredited_individual,
           user_account_email: test_user.email,
           user_account_icn: test_user.icn,
           poa_code:)
  end

  let!(:representative) do
    create(:representative,
           :vso,
           representative_id: accredited_individual.accredited_individual_registration_number,
           poa_codes: [poa_code])
  end

  let!(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
  let!(:other_vso) { create(:organization, poa: other_poa_code, can_accept_digital_poa_requests: true) }

  let(:claimant) { create(:user_account, icn: '1008714701V416111') }
  let!(:poa_request) do
    create(:power_of_attorney_request, :with_veteran_claimant, poa_code:, accredited_individual: representative,
                                                               accredited_organization: vso, claimant:)
  end
  let!(:other_poa_request) { create(:power_of_attorney_request, :with_veteran_claimant, poa_code: other_poa_code) }

  let(:time) { '2024-12-21T04:45:37.000Z' }
  let(:time_plus_one_day) { '2024-12-22T04:45:37.000Z' }

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    context 'when providing incomplete search params' do
      it 'returns a 400 error' do
        post('/accredited_representative_portal/v0/claimant/power_of_attorney_requests', params: {
               first_name: 'John', last_name: 'Smith', dob: '1980-01-01', ssn: ''
             })
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when providing complete search params' do
      it 'returns only matching power of attorney requests' do
        VCR.use_cassette('mpi/find_candidate/valid_icn_full') do
          post('/accredited_representative_portal/v0/claimant/power_of_attorney_requests', params: {
                 first_name: 'John', last_name: 'Smith', dob: '1980-01-01', ssn: '666-66-6666'
               })
        end
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response.map { |poa| poa['id'] }).to eq([poa_request.id])
      end
    end
  end
end
