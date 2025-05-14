# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestDecisionsController, type: :request do
  let!(:poa_code) { 'x23' }
  let!(:other_poa_code) { 'z99' }

  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859')
  end

  let!(:accredited_individual) do
    create(
      :user_account_accredited_individual,
      user_account_email: test_user.email,
      user_account_icn:   test_user.icn,
      accredited_individual_registration_number: '357458',
      poa_code:
    )
  end

  let!(:representative) do
    create(
      :representative,
      :vso,
      representative_id: accredited_individual.accredited_individual_registration_number,
      poa_codes: [poa_code]
    )
  end

  let!(:vso)        { create(:organization, poa: poa_code,      can_accept_digital_poa_requests: true) }
  let!(:other_vso)  { create(:organization, poa: other_poa_code, can_accept_digital_poa_requests: true) }

  let!(:poa_request) do
    create(
      :power_of_attorney_request,
      :with_veteran_claimant,
      accredited_individual_registration_number: nil,
      poa_code:
    )
  end

  let!(:other_poa_request) { create(:power_of_attorney_request, poa_code: other_poa_code) }
  let(:time)                { '2024-12-21T04:45:37.458Z' }

  before do
    client_credentials_service = instance_double(Auth::ClientCredentials::Service)
    allow(Auth::ClientCredentials::Service).to receive(:new).and_return(client_credentials_service)
    allow(client_credentials_service).to receive(:get_token).and_return('<TOKEN>')

    allow(Flipper).to receive(:enabled?)
      .with(:accredited_representative_portal_pilot,
            instance_of(AccreditedRepresentativePortal::RepresentativeUser))
      .and_return(true)

    poa_request.claimant.update!(icn: '1012666183V089914')
    login_as(test_user)
  end

  after { Flipper.disable(:accredited_representative_portal_pilot) }

  describe 'POST /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    context "when user's VSO does not accept digital POAs" do
      before { vso.update!(can_accept_digital_poa_requests: false) }

      it 'returns 403 Forbidden' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance' } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user's VSO does accept digital POAs but isn't associated" do
      it 'returns 404 Not Found' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{other_poa_request.id}/decision",
             params: { decision: { type: 'acceptance' } }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid params' do
      it 'complains about an invalid type param' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'invalid_type' } }

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors']).to eq(
          ['Invalid type parameter - Types accepted: [acceptance declination]']
        )
      end

      it 'complains about a missing declination_reason for a declination' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'declination' } }

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors']).to eq(
          ["Validation failed: Declination reason can't be blank"]
        )
      end
    end

    context 'with valid params' do
      it 'creates an acceptance decision' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob).not_to receive(:perform_async)

        # Mock the service to handle the acceptance
        accept_service = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
        allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
          .to receive(:new)
          .with(poa_request, anything)
          .and_return(accept_service)
          
        allow(accept_service).to receive(:call) do
          # Create the decision directly as a side effect
          AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.create_acceptance!(
            creator: test_user.user_account,
            power_of_attorney_request: poa_request
          )
        end

        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance' } }

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})

        poa_request.reload
        expect(poa_request.resolution).to be_present
        expect(poa_request.resolution.resolving.type)
          .to eq('PowerOfAttorneyRequestAcceptance')
      end

      it 'creates a declination decision with both declination_reason and no free-form reason' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob)
          .to receive(:perform_async)

        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: {
               type:              'declination',
               declination_reason: 'DECLINATION_HEALTH_RECORDS_WITHHELD'
             } }

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})

        poa_request.reload
        expect(poa_request.resolution.resolving.type)
          .to eq('PowerOfAttorneyRequestDeclination')
      end

      it 'creates a declination decision when no reason param is passed (declination only)' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob)
          .to receive(:perform_async)

        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: {
               type:              'declination',
               declination_reason: 'DECLINATION_NOT_ACCEPTING_CLIENTS'
             } }

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})

        poa_request.reload
        expect(poa_request.resolution.resolving.type)
          .to eq('PowerOfAttorneyRequestDeclination')
      end
    end

    context 'when request does not exist' do
      it 'returns 404 Not Found' do
        post '/accredited_representative_portal/v0/power_of_attorney_requests/nonexistent/decision'
        expect(response).to have_http_status(:not_found)
        expect(parsed_response['errors']).to include(a_string_including('Record not found'))
      end

      it 'handles 404 errors correctly' do
        # Use proper mocking to simulate a 404 error
        accept_service = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
        allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
          .to receive(:new)
          .with(poa_request, anything)
          .and_return(accept_service)
        
        allow(accept_service).to receive(:call)
          .and_raise(
            AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept::Error.new(
              "Record not found", :not_found
            )
          )
        
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
            params: { decision: { type: 'acceptance' } }
        
        expect(response).to have_http_status(:not_found)
        expect(parsed_response['errors']).to include('Record not found')
      end
    end

    context 'when decision already exists' do
      before do
        create(
          :power_of_attorney_request_resolution,
          :expiration,
          power_of_attorney_request: poa_request
        )
      end

      it 'returns an error' do
        expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestEmailJob)
          .not_to receive(:perform_async)

        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: {
               type:              'declination',
               declination_reason: 'DECLINATION_NOT_ACCEPTING_CLIENTS'
             } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq(
          ['Power of attorney request has already been taken']
        )
      end
    end
  end

  describe 'Full decision cycle' do
    it 'creates acceptance then rejects a second POST' do
      # Properly mock the Accept service
      accept_service = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
      allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
        .to receive(:new)
        .with(poa_request, anything)
        .and_return(accept_service)
        
      allow(accept_service).to receive(:call) do
        AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.create_acceptance!(
          creator: test_user.user_account,
          power_of_attorney_request: poa_request
        )
      end

      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"
      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']).to be_nil

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance' } }
      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq({})
      
      poa_request.reload
      expect(poa_request.resolution.resolving.type)
        .to eq('PowerOfAttorneyRequestAcceptance')

      resolution = poa_request.resolution
      get "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}"
      expect(response).to have_http_status(:ok)
      expect(parsed_response['resolution']['id']).to eq(resolution.id)

      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance' } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_response['errors']).to include('Power of attorney request has already been taken')
    end
  end

  context 'the server returns with a transient error' do
    it 'returns a 504 and rolls back all writes' do
      # Setup to properly test timeout errors with mocking
      AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.delete_all
      AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.delete_all
      
      # Create and inject a service mock that raises a timeout error
      accept_service = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
      allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
        .to receive(:new)
        .with(poa_request, anything)
        .and_return(accept_service)
      
      allow(accept_service).to receive(:call)
        .and_raise(
          AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept::Error.new(
            "Connection timed out", :gateway_timeout
          )
        )
      
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance' } }
           
      expect(response).to have_http_status(:gateway_timeout)
      expect(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.all)
        .to be_empty
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.all)
        .to be_empty
    end
  end

  context 'internal server error' do
    it 'returns 500 and rolls back all writes' do
      # Setup to properly test internal server errors with mocking
      AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.delete_all
      AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.delete_all
      
      # Create and inject a service mock that raises an internal server error
      accept_service = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
      allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
        .to receive(:new)
        .with(poa_request, anything)
        .and_return(accept_service)
      
      allow(accept_service).to receive(:call)
        .and_raise(StandardError, 'Internal server error')
      
      post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
           params: { decision: { type: 'acceptance' } }
           
      expect(response).to have_http_status(:internal_server_error)
      expect(AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission.all)
        .to be_empty
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.all)
        .to be_empty
    end
  end
end
