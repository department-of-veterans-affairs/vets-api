# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestDecisionsController, type: :request do
  let!(:poa_code) { 'x23' }
  let!(:other_poa_code) { 'z99' }

  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859', all_emails: ['test@va.gov'])
  end

  let!(:representative) do
    create(
      :representative,
      :vso,
      email: test_user.email,
      representative_id: Faker::Number.unique.number(digits: 6),
      poa_codes: [poa_code]
    )
  end

  let!(:vso)        { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }
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
  let(:time) { '2024-12-21T04:45:37.458Z' }

  before do
    client_credentials_service = instance_double(Auth::ClientCredentials::Service)
    allow(Auth::ClientCredentials::Service).to receive(:new).and_return(client_credentials_service)
    allow(client_credentials_service).to receive(:get_token).and_return('<TOKEN>')

    poa_request.claimant.update!(icn: '1012666183V089914')
    login_as(test_user)

    # Enable feature flag for tests
    Flipper.enable(:send_poa_to_corpdb, test_user)
  end

  def stub_ar_monitoring(controller: 'power_of_attorney_request_decisions', action: 'create')
    span_double = double('span', set_tag: true)
    monitor = instance_double(
      AccreditedRepresentativePortal::Monitoring,
      track_duration: true,
      track_count: true
    )
    allow(AccreditedRepresentativePortal::Monitoring).to receive(:new).and_call_original
    allow(AccreditedRepresentativePortal::Monitoring).to receive(:new)
      .with(
        'accredited-representative-portal',
        default_tags: array_including("controller:#{controller}", "action:#{action}")
      ).and_return(monitor)
    allow(monitor).to receive(:trace) { |_, &blk| blk&.call(span_double) }
    monitor
  end

  def expect_poa_metrics(monitor:, decision:, request:)
    expected_tags = array_including("poa_code:#{request.power_of_attorney_holder_poa_code}",
                                    "decision:#{decision}")
    expect(monitor).to have_received(:track_duration).with(
      'ar.poa.request.duration',
      from: request.created_at,
      tags: expected_tags
    )
    metric = if decision == 'accepted'
               'ar.poa.request.accepted.duration'
             else
               'ar.poa.request.declined.duration'
             end
    expect(monitor).to have_received(:track_duration).with(
      metric,
      from: request.created_at,
      tags: expected_tags
    )
  end

  describe 'POST /accredited_representative_portal/v0/power_of_attorney_requests/:id/decision' do
    context "when user's VSO does not accept digital POAs" do
      before { vso.update!(can_accept_digital_poa_requests: false) }

      it 'returns 403 Forbidden' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance' } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when POA request is withdrawn' do
      let!(:withdrawn_request) do
        resolution = create(:power_of_attorney_request_resolution, :replacement)
        resolution.power_of_attorney_request
      end

      it 'returns 404 Not Found and does not process a decision' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{withdrawn_request.id}/decision",
             params: { decision: { type: 'acceptance' } }

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to eq({ 'errors' => ['Record not found'] })
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

      it 'complains about a missing key for a declination' do
        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'declination' } }

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors']).to eq(
          ["Validation failed: Declination reason can't be blank"]
        )
      end
    end

    context 'with valid params' do
      before do
        # Spy on the job, but only if feature flag is enabled
        allow(AccreditedRepresentativePortal::SendPoaRequestToCorpDbJob).to receive(:perform_async)
      end

      it 'creates an acceptance decision and enqueues SendPoaRequestToCorpDbJob if feature flag enabled' do
        monitor = stub_ar_monitoring

        accept_service = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
        allow(AccreditedRepresentativePortal::PowerOfAttorneyRequestService::Accept)
          .to receive(:new)
          .with(poa_request, anything, anything)
          .and_return(accept_service)

        allow(accept_service).to receive(:call) do
          AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.create_acceptance!(
            creator_id: test_user.user_account_uuid,
            power_of_attorney_holder_memberships: test_user.power_of_attorney_holder_memberships,
            power_of_attorney_request: poa_request
          )
        end

        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance' } }

        expect(response).to have_http_status(:ok)
        expect(AccreditedRepresentativePortal::SendPoaRequestToCorpDbJob)
          .to have_received(:perform_async)
          .with(poa_request.id)

        poa_request.reload
        expect(poa_request.resolution.resolving.type).to eq('PowerOfAttorneyRequestAcceptance')
        expect_poa_metrics(monitor:, decision: 'accepted', request: poa_request)
      end

      it 'does not enqueue SendPoaRequestToCorpDbJob if feature flag disabled' do
        Flipper.disable(:send_poa_to_corpdb, test_user)

        allow(AccreditedRepresentativePortal::SendPoaRequestToCorpDbJob).to receive(:perform_async)

        # Stub process_acceptance to just render OK
        allow_any_instance_of(
          AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestDecisionsController
        ).to receive(:process_acceptance) do |controller|
          controller.render json: {}, status: :ok
        end

        post "/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}/decision",
             params: { decision: { type: 'acceptance' } }

        expect(response).to have_http_status(:ok)
        expect(AccreditedRepresentativePortal::SendPoaRequestToCorpDbJob).not_to have_received(:perform_async)
      end
    end
  end
end
