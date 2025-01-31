# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestDecisionsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:poa_request) do
    create(:power_of_attorney_request,
           power_of_attorney_holder_poa_code: '095',
           accredited_individual_registration_number: '999999999999')
  end

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
    Flipper.enable(:accredited_representative_portal_pilot)
    poa_request.claimant.update(icn: '1012666183V089914')
    login_as(test_user)
  end

  describe 'POST /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    context 'with invalid params' do
      it 'complains about an invalid type param' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'invalid_type', reason: nil } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq([
                                                  'Invalid type parameter - Types accepted: [acceptance declination]'
                                                ])
      end

      it 'complains about an invalid reason param' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: 'not allowed to give reasons for these' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq(
          ['Reason must be blank']
        )
      end

      it 'rep does not have poa for veteran' do
        poa_request.update(power_of_attorney_holder_poa_code: '111',
                           accredited_individual_registration_number: '1111111111')

        VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney_decision/404_response.yml') do
          post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
               params: { decision: { type: 'acceptance', reason: nil } }
        end
        expect(response).to have_http_status(:not_found)
        poa_request.reload

        expect(poa_request.resolution.present?).to be(true)
      end
    end

    it 'creates acceptance decision with veteran claimant' do
      VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney_decision/202_response.yml') do
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
      expect(parsed_response['errors']).to eq(
        ["Couldn't find AccreditedRepresentativePortal::PowerOfAttorneyRequest with 'id'=a"]
      )
    end

    it 'returns an error if decision already exists' do
      create(:power_of_attorney_request_resolution, :expiration,
             power_of_attorney_request: poa_request)

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
      VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney_decision/202_response.yml') do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance', reason: nil } }
      end

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      poa_request.reload

      expect(poa_request.resolution.present?).to be(true)
      expect(poa_request.resolution.resolving.present?).to be(true)
      expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')

      # --------------
      # GET REQUEST
      resolution = poa_request.reload.resolution
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']['id']).to eq(resolution.id)

      # --------------
      # POST REQUEST
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance', reason: nil } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_response['errors']).to eq(
        ['Power of attorney request has already been taken']
      )
    end
  end
end
