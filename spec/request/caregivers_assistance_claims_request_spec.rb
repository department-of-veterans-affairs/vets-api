# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Caregivers Assistance Claims', type: :request do
  let(:headers) do
    {
      'ACCEPT' => 'application/json',
      'CONTENT_TYPE' => 'application/json',
      'HTTP_X_KEY_INFLECTION' => 'camel'
    }
  end
  let(:uri) { 'http://localhost:3000' }
  let(:endpoint) { uri + '/v0/caregivers_assistance_claims' }
  let(:build_valid_form_submission) { -> { VetsJsonSchema::EXAMPLES['10-10CG'].clone } }
  let(:get_schema) { -> { VetsJsonSchema::SCHEMAS['10-10CG'].clone } }

  shared_examples_for 'any invalid submission' do
    it 'requires a namcespace of caregivers_assistance_claim' do
      body = {}
      post endpoint, params: body, headers: headers

      expect(response).to have_http_status(:bad_request)

      res_body = JSON.parse(response.body)

      expect(res_body['errors'].count).to eq(1)
      expect(res_body['errors'][0]['title']).to eq('Missing parameter')
      expect(res_body['errors'][0]['detail']).to eq('The required parameter "caregivers_assistance_claim", is missing')
    end

    it 'prevents attributes undefined in schema from being submitted' do
      body = { caregivers_assistance_claim: { form: JSON(anAttrNotInSchema: 'some value') } }.to_json
      post endpoint, params: body, headers: headers

      expect(response.code).to eq('422')

      res_body = JSON.parse(response.body)

      bad_attr_error = res_body['errors'].find { |error| error['title'].include?('anAttrNotInSchema') }

      expect(bad_attr_error).to be_present
      expect(res_body['errors'][0]['title']).to include("Form The property '#/' contains additional properties")
      expect(res_body['errors'][0]['detail']).to be_present
      expect(res_body['errors'][0]['code']).to eq('100')
      expect(res_body['errors'][0]['source']['pointer']).to eq('data/attributes/form')
      expect(res_body['errors'][0]['status']).to eq('422')
    end

    it 'provides formatted errors when missing required property' do
      form_data = build_valid_form_submission.call
      required_property = get_schema.call['required'][0]

      form_data.delete(required_property)

      body = { caregivers_assistance_claim: { form: form_data.to_json } }.to_json
      post endpoint, params: body, headers: headers

      expect(response.code).to eq('422')

      res_body = JSON.parse(response.body)

      expect(res_body['errors'].length).to eq(1)

      schema_error = res_body['errors'][0]

      expect(schema_error['title']).to include(
        "Form The property '#/' did not contain a required property of '#{required_property}'"
      )
      expect(schema_error['detail']).to include(
        "form - The property '#/' did not contain a required property of '#{required_property}'"
      )
      expect(schema_error['code']).to eq('100')
      expect(schema_error['source']['pointer']).to eq('data/attributes/form')
      expect(schema_error['status']).to eq('422')
    end
  end

  describe 'POST /v0/caregivers_assistance_claims' do
    context 'when unauthenticated' do
      it_behaves_like 'any invalid submission'

      timestamp = Date.parse('2020-03-09T06:48:59-04:00')

      it 'can submit a valid submission', run_at: timestamp.iso8601 do
        form_data = build_valid_form_submission.call

        body = { caregivers_assistance_claim: { form: form_data.to_json } }.to_json

        VCR.use_cassette 'carma/submissions/create/201' do
          post endpoint, params: body, headers: headers
        end

        expect(response.code).to eq('200')

        res_body = JSON.parse(response.body)

        expect(res_body['data']).to be_present
        expect(res_body['data']['type']).to eq 'form1010cg_submissions'
        expect(DateTime.parse(res_body['data']['attributes']['submittedAt'])).to eq timestamp
        expect(res_body['data']['attributes']['confirmationNumber']).to be_present
      end
    end
  end
end
