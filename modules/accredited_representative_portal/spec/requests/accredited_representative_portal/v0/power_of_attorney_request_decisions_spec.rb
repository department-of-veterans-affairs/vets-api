# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestDecisionsController, type: :request do
  let!(:poa_code) { 'x23' }
  let!(:other_poa_code) { 'z99' }

  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859')
  end

  let!(:accredited_individual) do
    create(:user_account_accredited_individual,
           user_account_email: test_user.email,
           user_account_icn: test_user.icn,
           accredited_individual_registration_number: '357458',
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

  let!(:poa_request) do
    create(
      :power_of_attorney_request,
      :with_veteran_claimant,
      accredited_individual_registration_number: nil,
      poa_code:
    )
  end
  let!(:other_poa_request) { create(:power_of_attorney_request, poa_code: other_poa_code) }

  let(:time) { '2024-12-21T04:45:37.458Z' }

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('<TOKEN>')
    allow(Flipper).to receive(:enabled?).with(
      :accredited_representative_portal_pilot,
      instance_of(AccreditedRepresentativePortal::RepresentativeUser)
    ).and_return(true)
    poa_request.claimant.update(icn: '1012666183V089914')

    login_as(test_user)
  end

  after { Flipper.disable(:accredited_representative_portal_pilot) }

  describe 'POST /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    context 'when user’s VSO does not accept digital POAs' do
      before do
        vso.update!(can_accept_digital_poa_requests: false)
      end

      it 'returns 403 Forbidden' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: nil } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user’s VSO does accept digital POAs but is not associated with this POA request' do
      it 'returns 404 Not Found' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{other_poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: nil } }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid params' do
      it 'complains about an invalid type param' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'invalid_type', reason: nil } }

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors']).to eq([
                                                  'Invalid type parameter - Types accepted: [acceptance declination]'
                                                ])
      end

      it 'complains about an invalid reason param' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: 'not allowed to give reasons for these' } }

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors']).to eq(['Validation failed: Reason must be blank'])
      end
    end

    context 'with valid params' do
      it 'creates an acceptance decision' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).not_to receive(:perform_async)
        use_cassette('202_response') do
          post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
               params: { decision: { type: 'acceptance', reason: nil } }
        end

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})
        poa_request.reload

        expect(poa_request.resolution).to be_present
        expect(poa_request.resolution.resolving).to be_present
        expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')
      end

      it 'creates a declination decision' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).to receive(:perform_async)
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'declination', reason: 'bad data' } }

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})
        poa_request.reload

        expect(poa_request.resolution).to be_present
        expect(poa_request.resolution.resolving).to be_present
        expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestDeclination')
      end
    end

    context 'when request does not exist' do
      it 'returns 404 Not Found' do
        post '/accredited_representative_portal/v0/power_of_attorney_requests/nonexistent/decision'

        expect(response).to have_http_status(:not_found)
        expect(parsed_response['errors']).to include(a_string_including('Record not found'))
      end

      it 'rep does not have poa for veteran' do
        use_cassette('404_response') do
          post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
               params: { decision: { type: 'acceptance', reason: nil } }
        end
        expect(response).to have_http_status(:not_found)
        poa_request.reload

        expect(poa_request.resolution.present?).to be(true)
      end
    end

    context 'when decision already exists' do
      before do
        create(:power_of_attorney_request_resolution, :expiration, power_of_attorney_request: poa_request)
      end

      it 'returns an error' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).not_to receive(:perform_async)
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'declination', reason: 'bad data' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq(['Power of attorney request has already been taken'])
      end
    end
  end

  describe 'Full decision cycle' do
    it 'creates acceptance decision with veteran claimant' do
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).not_to receive(:perform_async)
      use_cassette('202_response') do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: nil } }
      end
      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      poa_request.reload

      expect(poa_request.resolution.present?).to be(true)
      expect(poa_request.resolution.resolving.present?).to be(true)
      expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')
    end

    it 'creates declination decision with proper params' do
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).to receive(:perform_async)
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'declination', reason: 'bad data' } }

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      poa_request.reload

      expect(poa_request.resolution.present?).to be(true)
      expect(poa_request.resolution.resolving.present?).to be(true)
      expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestDeclination')
    end

    it 'returns an error if request does not exist' do
      post '/accredited_representative_portal/v0/power_of_attorney_requests/a/decision'

      expect(response).to have_http_status(:not_found)
      expect(parsed_response['errors']).to eq(['Record not found'])
    end

    it 'returns an error if decision already exists' do
      create(:power_of_attorney_request_resolution, :expiration,
             power_of_attorney_request: poa_request)
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).not_to receive(:perform_async)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'declination', reason: 'bad data' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_response['errors']).to eq(
        ['Power of attorney request has already been taken']
      )
    end
  end

  context 'the server returns with a transient error' do
    let(:lh_config) { double }

    it 'returns an error, does not save anything' do
      allow(Common::Client::Base).to receive(:configuration).and_return lh_config
      allow(lh_config).to receive(:post).and_raise(Faraday::TimeoutError)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: '' } }

      expect(response).to have_http_status(:gateway_timeout)
      expect(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.all).to be_empty
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.all).to be_empty
    end
  end

  context 'internal server error' do
    let(:error) { StandardError.new('boom') }
    let(:lh_config) { double }

    it 'returns an error, does not save anything' do
      allow(Common::Client::Base).to receive(:configuration).and_return lh_config
      allow(lh_config).to receive(:post).and_raise(error)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: '' } }

      expect(response).to have_http_status(:internal_server_error)
      expect(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.all).to be_empty
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.all).to be_empty
    end
  end

  describe 'full cycle for decision api' do
    it 'returns the correct results for POST GET POST GET' do
      # --------------
      # GET REQUEST
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"
      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']).to be_nil

      # --------------
      # POST REQUEST
      use_cassette('202_response') do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: nil } }
      end

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      poa_request.reload

      expect(poa_request.resolution).to be_present
      expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')

      # GET request after decision
      resolution = poa_request.reload.resolution
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']['id']).to eq(resolution.id)

      # Attempt to POST decision again (should fail)
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:bad_request)
      expect(parsed_response['errors']).to eq(
        ['Validation failed: Power of attorney request has already been taken']
      )
    end
  end
end
