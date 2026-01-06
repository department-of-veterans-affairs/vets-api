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
    login_as(representative_user)
  end

  describe 'POST /accredited_representative_portal/v0/form21a' do
    context 'when the user is not LOA3' do
      let(:non_loa3_user) { create(:representative_user) }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_form_21a)
          .and_return(true)

        allow_any_instance_of(AccreditedRepresentativePortal::V0::Form21aController)
          .to receive(:current_user)
          .and_return(non_loa3_user)

        allow(non_loa3_user).to receive(:loa).and_return({ current: 1, highest: 1 })

        login_as(non_loa3_user)
      end

      it 'returns 404 and does not call the service' do
        expect(AccreditationService).not_to receive(:submit_form21a)
        make_post_request
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with valid JSON' do
      let!(:in_progress_form) { create(:in_progress_form, form_id: '21a', user_uuid: representative_user.uuid) }

      it 'logs success and destroys in-progress form' do
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
      it 'logs and returns no content' do
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

    context 'when the Form 21a feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_form_21a)
          .and_return(false)
      end

      it 'returns 404 Not Found (routing error)' do
        make_post_request
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when nested form JSON is invalid' do
      let(:payload) do
        {
          form21aSubmission: {
            form: 'not-json' # will raise JSON::ParserError inside parse_request_body
          }
        }.to_json
      end

      it 'logs and returns a bad request for invalid nested JSON' do
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

    context 'when a connection error occurs' do
      it 'logs the error and returns a 503 (ConnectionFailed)' do
        allow(AccreditationService).to receive(:submit_form21a)
          .and_raise(Faraday::ConnectionFailed.new('connection down'))

        expect(Rails.logger).to receive(:error).with(
          a_string_including('Form21aController: Network error: Faraday::ConnectionFailed')
        )

        make_post_request
        expect(response).to have_http_status(:service_unavailable)
        expect(parsed_response).to eq('errors' => 'Service temporarily unavailable')
      end
    end
  end

  describe 'POST /accredited_representative_portal/v0/form21a/:details_slug' do
    subject(:make_post_request) do
      post(path, params: { file: }, headers:)
    end

    let(:file) do
      fixture_file_upload(
        Rails.root.join('modules',
                        'accredited_representative_portal',
                        'spec',
                        'fixtures',
                        'files',
                        '21_686c_empty_form.pdf'),
        'application/pdf'
      )
    end

    let(:slug) { 'conviction-details' }
    let(:path) { "/accredited_representative_portal/v0/form21a/#{slug}" }

    let!(:in_progress_form) do
      create(
        :in_progress_form,
        form_id: '21a',
        user_uuid: representative_user.uuid,
        form_data: {}.to_json
      )
    end

    before do
      allow(Flipper).to receive(:enabled?)
        .with(:accredited_representative_portal_form_21a)
        .and_return(true)
      login_as(representative_user)
    end

    context 'when the user is not LOA3' do
      let(:non_loa3_user) { create(:representative_user) }
      let(:slug) { 'conviction-details' }
      let(:path) { "/accredited_representative_portal/v0/form21a/#{slug}" }
      let(:file) do
        fixture_file_upload(
          Rails.root.join('modules',
                          'accredited_representative_portal',
                          'spec',
                          'fixtures',
                          'files',
                          '21_686c_empty_form.pdf'),
          'application/pdf'
        )
      end

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_form_21a)
          .and_return(true)

        allow_any_instance_of(AccreditedRepresentativePortal::RepresentativeUser)
          .to receive(:loa)
          .and_return({ current: 1, highest: 1 })

        login_as(non_loa3_user)
      end

      it 'returns 404 and does not process the file' do
        expect(Rails.logger).not_to receive(:info).with(
          a_string_including('Form21aController: Received details upload')
        )

        expect { post(path, params: { file: }, headers:) }
          .not_to change(AccreditedRepresentativePortal::Form21aAttachment, :count)

        expect(response).to have_http_status(:not_found)
        expect(parsed_response).to match(
          'errors' => [
            hash_including(
              'title' => 'Not found',
              'status' => '404'
            )
          ]
        )
      end
    end

    context 'when attachment fails validation' do
      before do
        allow_any_instance_of(AccreditedRepresentativePortal::Form21aAttachment)
          .to receive(:save!)
          .and_raise(ActiveRecord::RecordInvalid.new(
                       AccreditedRepresentativePortal::Form21aAttachment.new
                     ))
      end

      it 'returns unprocessable entity with generic error message' do
        make_post_request

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to eq('Unable to store document')
      end
    end

    context 'when file upload fails integrity checks' do
      let(:file) do
        fixture_file_upload(
          Rails.root.join('modules',
                          'accredited_representative_portal',
                          'spec',
                          'fixtures',
                          'files',
                          'invalid_21a_extension.png'),
          'image/png'
        )
      end

      it 'returns unprocessable entity with error message' do
        make_post_request

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors']).to be_present
      end
    end

    context 'with a valid slug and file' do
      it 'creates an attachment, updates the in-progress form, and returns confirmation data' do
        allow(Rails.logger).to receive(:info).and_call_original

        expect do
          make_post_request
        end.to change(AccreditedRepresentativePortal::Form21aAttachment, :count).by(1)

        expect(Rails.logger).to have_received(:info).with(
          a_string_including(
            "Form21aController: Received details upload for slug=#{slug} user_uuid=#{representative_user.uuid}"
          )
        )

        expect(response).to have_http_status(:ok)

        attrs = parsed_response.fetch('data').fetch('attributes')
        expect(attrs['confirmationCode']).to be_present
        expect(attrs['name']).to eq('21_686c_empty_form.pdf')
        expect(attrs['size']).to eq(file.size)
        expect(attrs['type']).to eq('application/pdf')
        expect(attrs['errorMessage']).to eq('')

        in_progress_form.reload
        form_data = JSON.parse(in_progress_form.form_data)

        documents = form_data['imprisonedDetailsDocuments']
        expect(documents).to be_an(Array)
        expect(documents.size).to eq(1)

        document = documents.first
        expect(document['name']).to eq('21_686c_empty_form.pdf')
        expect(document['size']).to eq(file.size)
        expect(document['type']).to eq('application/pdf')
        expect(document['confirmationCode']).to eq(attrs['confirmationCode'])
      end
    end

    context 'when file is missing' do
      subject(:make_post_request) { post(path, params: {}, headers:) }

      it 'returns a bad request with an error message' do
        make_post_request

        expect(response).to have_http_status(:bad_request)
        expect(parsed_response).to eq('errors' => 'file is required')
      end
    end

    context 'with an invalid slug' do
      let(:slug) { 'not-a-real-slug' }
      let(:path) { "/accredited_representative_portal/v0/form21a/#{slug}" }

      it 'returns 404 due to routing constraint' do
        make_post_request
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_form_21a)
          .and_return(false)
      end

      it 'returns 404' do
        make_post_request
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when there is no in-progress form for the user' do
      let!(:in_progress_form) { nil }

      before do
        InProgressForm.where(form_id: '21a', user_uuid: representative_user.uuid).delete_all
      end

      it 'returns 404 via routing_error' do
        make_post_request
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
