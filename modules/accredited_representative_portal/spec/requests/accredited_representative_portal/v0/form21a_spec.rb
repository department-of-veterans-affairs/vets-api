# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe 'AccreditedRepresentativePortal::V0::Form21a', type: :request do
  subject(:make_post_request) { post('/accredited_representative_portal/v0/form21a', params: payload, headers:) }

  let(:form_data) do
    {
      'firstName' => 'John',
      'lastName' => 'Doe',
      'homePhone' => '555-555-1234',
      'homeEmail' => 'john.doe@example.com',
      'applicationStatusId' => 1,
      'accreditationTypeId' => 2,
      'genderId' => 1,
      'instructionAcknowledge' => true,
      'employmentStatusId' => 3,
      'icnNo' => representative_user.icn,
      'uId' => representative_user.uuid
    }
  end

  let(:json) { form_data.to_json }
  let(:payload) do
    {
      form21aSubmission: {
        form: json
      }
    }.to_json
  end

  let(:mock_schema) do
    {
      '$schema' => 'http://json-schema.org/draft-04/schema#',
      'title' => 'Apply to become a VA-accredited attorney or claims agent',
      'type' => 'object',
      'properties' => { 'firstName' => { 'type' => 'string' } },
      'required' => ['firstName'],
      'additionalProperties' => false
    }
  end

  let(:representative_user) { create(:representative_user) }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(representative_user)
  end

  after { Flipper.disable(:accredited_representative_portal_pilot) }

  describe 'POST /accredited_representative_portal/v0/form21a' do
    context 'with valid JSON' do
      let!(:in_progress_form) { create(:in_progress_form, form_id: '21a', user_uuid: representative_user.uuid) }

      it 'logs success and destroys in-progress form',
         skip: 'Test has been flaky - see: ' \
               'https://github.com/department-of-veterans-affairs/va.gov-team/issues/102880' do
        get('/accredited_representative_portal/v0/in_progress_forms/21a')
        expect(response).to have_http_status(:ok)
        expect(parsed_response.keys).to contain_exactly('formData', 'metadata')

        allow(AccreditationService).to receive(:submit_form21a) do |form_array, _uuid|
          form = form_array.first
          expect(form['icnNo']).to eq(representative_user.icn)
          expect(form['uId']).to eq(representative_user.uuid)
          instance_double(Faraday::Response, success?: true, body: { result: 'success' }, status: 201)
        end

        expect(Rails.logger).to receive(:info).with(
          a_string_including(
            'Form21aController: Form 21a successfully submitted to OGC service by user with' \
            " user_uuid=#{representative_user.uuid} - Response: {:result=>\"success\"}"
          )
        )

        make_post_request
        expect(response).to have_http_status(:created)
        expect(parsed_response).to eq('result' => 'success')

        get('/accredited_representative_portal/v0/in_progress_forms/21a')
        expect(response).to have_http_status(:ok)
        expect(parsed_response).to eq({})
      end
    end

    context 'with invalid JSON' do
      let(:payload) { 'invalid_json' }

      it 'logs and returns a bad request' do
        expect(Rails.logger).to receive(:error).with(
          a_string_including(
            'Form21aController: Invalid JSON in request body for user with' \
            " user_uuid=#{representative_user.uuid}."
          )
        )

        make_post_request
        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors']).to include('Invalid JSON')
      end
    end

    context 'when form does not match schema' do
      let(:form_data) { { 'firstName' => 1234 } }

      before do
        allow(VetsJsonSchema::SCHEMAS).to receive(:[]).with('21A').and_return(mock_schema)
      end

      it 'logs and returns a bad request' do
        expect(Rails.logger).to receive(:error).with(
          a_string_including(
            "Form21aController: Invalid JSON in request body for user with user_uuid=#{representative_user.uuid}"
          )
        )

        make_post_request
        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors']).to match(/firstName.*type/)
        expect(parsed_response['errors']).to match(/icnNo|uId/)
      end
    end

    context 'when service returns a blank response' do
      it 'logs and returns no content',
         skip: 'Test has been flaky - see: ' \
               'https://github.com/department-of-veterans-affairs/va.gov-team/issues/102880' do
        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: false, body: nil, status: 204)
        )

        expect(Rails.logger).to receive(:error).with(
          a_string_including(
            'Form21aController: Blank or unparsable response from external OGC service'
          )
        )

        make_post_request
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when service returns a 400 with validation errors' do
      let(:error_body) do
        {
          'errors' => {
            '[0].education[0].InstitutionTypeId' => [
              'The InstitutionTypeId field is required.'
            ]
          },
          'type' => 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
          'title' => 'One or more validation errors occurred.',
          'status' => 400,
          'traceId' => '00-685b4dee0000000030e6cefe3c3fd8ff-25aa3dda711bee62-01'
        }
      end

      before do
        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: false, status: 400, body: error_body)
        )
      end

      it 'logs, renders error JSON and returns 400' do
        expect(Rails.logger).to receive(:error).with(
          a_string_including('OGC service returned error response (status=400)')
        )

        make_post_request
        expect(response).to have_http_status(:bad_request)
        expect(parsed_response).to eq(error_body)
      end
    end

    context 'when service returns a 503' do
      let(:error_body) { { 'errors' => { 'service' => ['Temporarily unavailable'] }, 'status' => 503 } }

      before do
        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: false, status: 503, body: error_body)
        )
      end

      it 'logs and returns a 503 with error body' do
        expect(Rails.logger).to receive(:error).with(
          a_string_including('OGC service returned error response (status=503)')
        )

        make_post_request
        expect(response).to have_http_status(:service_unavailable)
        expect(parsed_response).to eq(error_body)
      end
    end

    context 'when an unexpected error occurs' do
      it 'logs and returns an internal server error' do
        allow_any_instance_of(AccreditedRepresentativePortal::V0::Form21aController)
          .to receive(:parse_request_body).and_raise(StandardError, 'Unexpected error')

        allow(Rails.logger).to receive(:error).and_call_original

        make_post_request

        expect(Rails.logger).to have_received(:error).with(
          a_string_including("ARP: Unexpected error occurred for user with user_uuid=#{representative_user.uuid}")
        )

        expect(response).to have_http_status(:internal_server_error)
        expect(parsed_response).to match(
          'errors' => [
            hash_including(
              'title' => 'Internal server error',
              'detail' => 'Internal server error',
              'code' => '500',
              'status' => '500'
            )
          ]
        )
      end
    end

    context 'when a network error occurs' do
      it 'logs the error and returns a 503' do
        allow(AccreditationService).to receive(:submit_form21a).and_raise(Faraday::TimeoutError.new('timeout'))

        expect(Rails.logger).to receive(:error).with(
          a_string_including('Form21aController: Network error: Faraday::TimeoutError')
        )

        make_post_request
        expect(response).to have_http_status(:service_unavailable)
        expect(parsed_response).to eq('errors' => 'Service temporarily unavailable')
      end
    end

    context 'when an unexpected error occurs in service call' do
      it 'logs the error and returns a 500' do
        allow(AccreditationService).to receive(:submit_form21a).and_raise(StandardError.new('boom'))

        expect(Rails.logger).to receive(:error).with(
          a_string_including('Form21aController: Unexpected error: StandardError')
        )

        make_post_request
        expect(response).to have_http_status(:internal_server_error)
        expect(parsed_response).to eq('errors' => 'Internal server error')
      end
    end

    context 'when form21aSubmission key is missing or nil' do
      let(:payload) { {}.to_json }

      it 'logs and returns a bad request' do
        expect(Rails.logger).to receive(:error).with(
          a_string_including(
            "Form21aController: Invalid JSON in request body for user with user_uuid=#{representative_user.uuid}"
          )
        )

        make_post_request
        expect(response).to have_http_status(:bad_request)
        expect(parsed_response['errors']).to include('Invalid JSON')
      end
    end
  end
end
