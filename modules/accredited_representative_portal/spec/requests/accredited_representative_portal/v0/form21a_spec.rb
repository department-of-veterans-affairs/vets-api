# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe 'AccreditedRepresentativePortal::V0::Form21a', type: :request do
  let(:valid_json) { { field: 'value' }.to_json }
  let(:invalid_json) { 'invalid json' }
  let(:mock_schema) do
    {
      '$schema' => 'http://json-schema.org/draft-04/schema#',
      'title' => 'Apply to become a VA-accredited attorney or claims agent',
      'type' => 'object',
      'properties' => {
        'firstName' => {
          'type' => 'string'
        }
      }
    }
  end
  let(:invalid_form) { { 'firstName' => 1234 }.to_json }
  let(:representative_user) { create(:representative_user) }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(representative_user)
  end

  after { Flipper.disable(:accredited_representative_portal_pilot) }

  describe 'POST /accredited_representative_portal/v0/form21a' do
    context 'with valid JSON' do
      let!(:in_progress_form) { create(:in_progress_form, form_id: '21a', user_uuid: representative_user.uuid) }

      it 'logs a successful submission and destroys in-progress form',
         skip: 'Test has been flaky - see: ' \
               'https://github.com/department-of-veterans-affairs/va.gov-team/issues/102880' do
        get('/accredited_representative_portal/v0/in_progress_forms/21a')
        expect(response).to have_http_status(:ok)
        expect(parsed_response.keys).to contain_exactly('formData', 'metadata')

        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: true, body: { result: 'success' }.to_json, status: 200)
        )

        expect(Rails.logger).to receive(:info).with(
          'Form21aController: Form 21a successfully submitted to OGC service ' \
          "by user with user_uuid=#{representative_user.uuid} - Response: {\"result\":\"success\"}"
        )

        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: valid_json, headers:)

        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq('result' => 'success')

        get('/accredited_representative_portal/v0/in_progress_forms/21a')
        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})
      end
    end

    context 'with invalid JSON' do
      it 'logs the error and returns a bad request status' do
        expect(Rails.logger).to receive(:error).with(
          "Form21aController: Invalid JSON in request body for user with user_uuid=#{representative_user.uuid}."
        )

        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: invalid_json, headers:)

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response).to eq('errors' => 'Invalid JSON')
      end
    end

    context 'form doestn match schema' do
      it 'logs the error and returns a bad request status' do
        allow(VetsJsonSchema::SCHEMAS).to receive(:[]).with('21A').and_return(mock_schema)

        expect(Rails.logger).to receive(:error).with(
          matching(
            %r{Form21aController: Invalid JSON in request body for user with user_uuid=#{representative_user.uuid}. \
Errors: The property '#/firstName' of type integer did not match the following type: string in schema \
[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}
          )
        )

        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: invalid_form, headers:)

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response).to eq('errors' => 'Invalid JSON')
      end
    end

    context 'when service returns a blank response' do
      it 'logs the error and returns no content status',
         skip: 'Test has been flaky - see: ' \
               'https://github.com/department-of-veterans-affairs/va.gov-team/issues/102880' do
        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: false, body: nil, status: 204)
        )

        expect(Rails.logger).to receive(:info).with(
          "Form21aController: Blank response from OGC service for user with user_uuid=#{representative_user.uuid}"
        )

        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: valid_json, headers:)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when service fails to parse response' do
      it 'logs the error and returns a bad gateway status' do
        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: false, body: { errors: 'Failed to parse response' }.to_json,
                                             status: 502)
        )

        expect(Rails.logger).to receive(:error).with(
          'Form21aController: Failed to parse response from external OGC service ' \
          "for user with user_uuid=#{representative_user.uuid}"
        )

        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: valid_json, headers:)

        expect(response).to have_http_status(:bad_gateway)
        expect(parsed_response).to eq('errors' => 'Failed to parse response')
      end
    end

    context 'when an unexpected error occurs' do
      it 'logs the error and returns an internal server error status' do
        allow_any_instance_of(AccreditedRepresentativePortal::V0::Form21aController)
          .to receive(:parse_request_body).and_raise(StandardError, 'Unexpected error')

        allow(Rails.logger).to receive(:error).and_call_original

        post '/accredited_representative_portal/v0/form21a'

        expect(Rails.logger).to have_received(:error).with(
          include(/ARP: Unexpected error occurred for user with user_uuid=#{representative_user.uuid}/)
        )

        expect(response).to have_http_status(:internal_server_error)
        expect(parsed_response).to match(
          'errors' => [
            {
              'title' => 'Internal server error',
              'detail' => 'Internal server error',
              'code' => '500',
              'status' => '500',
              'meta' => a_hash_including(
                'exception' => 'Unexpected error',
                'backtrace' => be_an(Array)
              )
            }
          ]
        )
      end
    end
  end
end
