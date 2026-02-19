# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DigitalFormsApi::V0::Submissions', type: :request do
  let(:submissions_service) { instance_double(DigitalFormsApi::Service::Submissions) }

  before do
    allow(DigitalFormsApi::Service::Submissions).to receive(:new).and_return(submissions_service)
  end

  describe 'POST /digital_forms_api/v0/submissions' do
    let(:payload) { { data: 'TEST' } }
    let(:metadata) do
      {
        formId: '99t-12345',
        veteranId: '123456789v12345',
        claimantId: 'another-identifier',
        epCode: '99999999',
        claimLabel: '99999999DPEBNAJRE'
      }
    end

    let(:params) do
      {
        payload:,
        metadata:,
        dry_run: false
      }
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post('/digital_forms_api/v0/submissions', params:)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      before { sign_in(create(:user)) }

      it 'returns submission context with immediate UUID and veteran association' do
        allow(submissions_service).to receive(:submit_with_context).and_return(
          {
            submission_uuid: 'a1ba50e4-e689-4852-bec7-2a66519f0ed3',
            form_id: '99t-12345',
            veteran_participant_id: '123456789v12345',
            claimant_participant_id: 'another-identifier'
          }
        )

        post('/digital_forms_api/v0/submissions', params:)

        expect(submissions_service).to have_received(:submit_with_context).with(
          { 'data' => 'TEST' },
          metadata,
          dry_run: false
        )
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['data']).to include(
          'submission_uuid' => 'a1ba50e4-e689-4852-bec7-2a66519f0ed3',
          'form_id' => '99t-12345',
          'veteran_participant_id' => '123456789v12345',
          'claimant_participant_id' => 'another-identifier'
        )
      end

      it 'returns bad gateway when submission UUID is missing from service response' do
        allow(submissions_service).to receive(:submit_with_context).and_return(
          {
            submission_uuid: nil,
            form_id: '99t-12345',
            veteran_participant_id: '123456789v12345',
            claimant_participant_id: 'another-identifier'
          }
        )

        post('/digital_forms_api/v0/submissions', params:)

        expect(response).to have_http_status(:bad_gateway)
      end

      it 'returns bad request when required metadata is missing' do
        invalid_params = params.deep_dup
        invalid_params[:metadata].delete(:formId)

        post '/digital_forms_api/v0/submissions', params: invalid_params

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'GET /digital_forms_api/v0/submissions/:id' do
    let(:uuid) { 'a1ba50e4-e689-4852-bec7-2a66519f0ed3' }

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/digital_forms_api/v0/submissions/#{uuid}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      before { sign_in(create(:user)) }

      it 'proxies submission retrieval response' do
        retrieval_response = instance_double(
          Faraday::Response,
          body: { submission: { submissionId: uuid, claimId: '123456789' } },
          status: 200
        )
        allow(submissions_service).to receive(:retrieve).with(uuid).and_return(retrieval_response)

        get "/digital_forms_api/v0/submissions/#{uuid}"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          'submission' => { 'submissionId' => uuid, 'claimId' => '123456789' }
        )
      end
    end
  end
end
