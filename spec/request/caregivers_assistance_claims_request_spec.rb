# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Caregivers Assistance Claims', type: :request do
  let(:uri) { 'http://localhost:3000' }
  let(:headers) do
    {
      'ACCEPT' => 'application/json',
      'CONTENT_TYPE' => 'application/json',
      'HTTP_X_KEY_INFLECTION' => 'camel'
    }
  end
  let(:build_valid_form_submission) { -> { VetsJsonSchema::EXAMPLES['10-10CG'].clone } }
  let(:get_schema) { -> { VetsJsonSchema::SCHEMAS['10-10CG'].clone } }

  shared_examples_for 'any invalid submission' do |endpoint:|
    it 'requires a namespace of caregivers_assistance_claim' do
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
    let(:endpoint) { uri + '/v0/caregivers_assistance_claims' }
    let(:vcr_options) do
      {
        record: :none,
        allow_unused_http_interactions: false,
        match_requests_on: %i[method uri host path]
      }
    end

    context 'when :stub_carma_responses is disabled' do
      it_behaves_like 'any invalid submission', endpoint: '/v0/caregivers_assistance_claims'

      timestamp = DateTime.parse('2020-03-09T06:48:59-04:00')

      it 'can submit a valid submission', run_at: timestamp.iso8601 do
        form_data = build_valid_form_submission.call

        body = { caregivers_assistance_claim: { form: form_data.to_json } }.to_json

        expect(Flipper).to receive(:enabled?).with(:stub_carma_responses).and_return(false).twice

        VCR.use_cassette 'mvi/find_candidate/valid', vcr_options do
          VCR.use_cassette 'carma/auth/token/200', vcr_options do
            VCR.use_cassette 'carma/submissions/create/201', vcr_options do
              VCR.use_cassette 'carma/attachments/upload/201', vcr_options do
                post endpoint, params: body, headers: headers
              end
            end
          end
        end

        expect(response.code).to eq('200')

        res_body = JSON.parse(response.body)

        expect(res_body['data']).to be_present
        expect(res_body['data']['type']).to eq 'form1010cg_submissions'
        expect(DateTime.parse(res_body['data']['attributes']['submittedAt'])).to eq timestamp
        expect(res_body['data']['attributes']['confirmationNumber']).to eq 'aB935000000F3VnCAK'
      end
    end

    context 'when :stub_carma_responses is enabled' do
      it_behaves_like 'any invalid submission', endpoint: '/v0/caregivers_assistance_claims'

      timestamp = DateTime.parse('2020-03-09T06:48:59-04:00')

      it 'will mock responses from CARMA', run_at: timestamp.iso8601 do
        form_data = build_valid_form_submission.call

        body = { caregivers_assistance_claim: { form: form_data.to_json } }.to_json

        expect(Flipper).to receive(:enabled?).with(:stub_carma_responses).and_return(true).twice

        VCR.use_cassette 'mvi/find_candidate/valid', vcr_options do
          post endpoint, params: body, headers: headers
        end

        expect(response.code).to eq('200')

        res_body = JSON.parse(response.body)

        expect(res_body['data']).to be_present
        expect(res_body['data']['type']).to eq 'form1010cg_submissions'
        expect(DateTime.parse(res_body['data']['attributes']['submittedAt'])).to eq timestamp
        expect(res_body['data']['attributes']['confirmationNumber']).to eq 'aB935000000F3VnCAK'
      end
    end
  end

  describe 'POST /v0/caregivers_assistance_claims/download_pdf' do
    let(:endpoint) { '/v0/caregivers_assistance_claims/download_pdf' }
    let(:response_pdf) { Rails.root.join 'tmp', 'pdfs', '10-10CG_from_response.pdf' }
    let(:expected_pdf) { Rails.root.join 'spec', 'fixtures', 'pdf_fill', '10-10CG', 'unsigned', 'simple.pdf' }

    after do
      File.delete(response_pdf) if File.exist?(response_pdf)
    end

    it_behaves_like 'any invalid submission', endpoint: '/v0/caregivers_assistance_claims/download_pdf'

    it 'returns a completed PDF', run_at: '2017-07-25 00:00:00 -0400' do
      form_data = get_fixture('pdf_fill/10-10CG/simple').to_json
      claim     = build(:caregivers_assistance_claim, form: form_data)
      body      = { caregivers_assistance_claim: { form: form_data } }.to_json

      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        form: form_data
      ).and_return(
        claim
      )

      expect(SecureRandom).to receive(:uuid).and_return('saved-claim-guid') # When the saved claim is initialized
      expect(SecureRandom).to receive(:uuid).and_return('file-name-uuid') # When controller generates it for filename

      post endpoint, params: body, headers: headers

      expect(response).to have_http_status(:ok)

      # download response conent (the pdf) to disk
      File.open(response_pdf, 'wb+') { |f| f.write(response.body) }

      # compare it with the pdf fixture
      expect(
        pdfs_fields_match?(response_pdf, expected_pdf)
      ).to eq(true)

      # ensure that the tmp file was deleted
      expect(
        File.exist?('tmp/pdfs/10-10CG_file-name-uuid.pdf')
      ).to eq(false)
    end
  end
end
