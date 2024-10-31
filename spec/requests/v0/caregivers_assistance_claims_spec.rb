# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/facilities/v1/client'

RSpec.describe 'V0::CaregiversAssistanceClaims', type: :request do
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

  before do
    allow_any_instance_of(Form1010cg::Auditor).to receive(:record)
    allow_any_instance_of(Form1010cg::Auditor).to receive(:record_caregivers)
    allow(Rails.logger).to receive(:debug)
  end

  describe 'POST /v0/caregivers_assistance_claims' do
    subject do
      post('/v0/caregivers_assistance_claims', params: body, headers:)
    end

    let(:valid_form_data) { get_fixture('pdf_fill/10-10CG/simple').to_json }
    let(:invalid_form_data) { '{}' }

    before do
      allow(SavedClaim::CaregiversAssistanceClaim).to receive(:new)
        .and_return(claim) # Ensure the same claim instance is used
    end

    context 'when the claim is valid' do
      let(:body) { { caregivers_assistance_claim: { form: valid_form_data } }.to_json }
      let(:claim) { build(:caregivers_assistance_claim, form: valid_form_data) }

      before do
        allow_any_instance_of(Form1010cg::Service).to receive(:assert_veteran_status)
        allow(Form1010cg::SubmissionJob).to receive(:perform_async)
      end

      context 'assert_veteran_status is successful' do
        it 'creates a new claim, enqueues a submission job, and returns claim id' do
          expect_any_instance_of(Form1010cg::Auditor).to receive(:record).with(:submission_attempt)
          expect_any_instance_of(Form1010cg::Auditor).to receive(:record_caregivers).with(claim)

          expect { subject }.to change(SavedClaim::CaregiversAssistanceClaim, :count).by(1)

          expect(Form1010cg::SubmissionJob).to have_received(:perform_async).with(claim.id)

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['id']).to eq(SavedClaim::CaregiversAssistanceClaim.last.id.to_s)
          expect(JSON.parse(response.body)['data']['type']).to eq('claim')
        end

        context 'when an unexpected error occurs saving claim' do
          let(:error_message) { 'Some unexpected error' }

          before do
            allow(claim).to receive(:save!).and_raise(StandardError.new(error_message))
          end

          it 'logs the error and re-raises it' do
            expect(Rails.logger).to receive(:debug).with(
              'CaregiverAssistanceClaim: error submitting claim',
              { saved_claim_guid: claim.guid, error: kind_of(StandardError) }
            )

            subject
            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end

      context 'assert_veteran_status error' do
        before do
          allow_any_instance_of(Form1010cg::Service).to receive(
            :assert_veteran_status
          ).and_raise(Form1010cg::Service::InvalidVeteranStatus)
        end

        it 'returns backend service exception' do
          expect(Rails.logger).not_to receive(:debug).with(
            'CaregiverAssistanceClaim: error submitting claim',
            { saved_claim_guid: claim.guid, error: instance_of(Form1010cg::Service::InvalidVeteranStatus) }
          )

          subject

          expect(response).to have_http_status(:service_unavailable)
          expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
            'Backend Service Outage'
          )
        end
      end
    end

    context 'when the claim is invalid' do
      let(:body) { { caregivers_assistance_claim: { form: invalid_form_data } }.to_json }
      let(:claim) { build(:caregivers_assistance_claim, form: invalid_form_data) }

      before do
        allow(PersonalInformationLog).to receive(:create!)
      end

      it 'logs the error and returns unprocessable entity' do
        expect_any_instance_of(Form1010cg::Auditor).to receive(:record).with(:submission_attempt)
        expect_any_instance_of(Form1010cg::Auditor).to receive(:record).with(:submission_failure_client_data,
                                                                             hash_including(
                                                                               claim_guid: claim.guid,
                                                                               errors: hash_including('#/': be_present)
                                                                             ))
        expect(Rails.logger).not_to receive(:debug).with(
          'CaregiverAssistanceClaim: error submitting claim',
          { saved_claim_guid: claim.guid,
            error: instance_of(Common::Exceptions::ValidationErrors) }
        )

        subject
        expect(PersonalInformationLog).to have_received(:create!).with(
          data: { form: claim.parsed_form },
          error_class: '1010CGValidationError'
        )

        expect(response).to have_http_status(:unprocessable_entity)

        res_body = JSON.parse(response.body)
        expected_errors = [
          { title: "did not contain a required property of 'veteran'", code: '100', status: '422' },
          { title: "#/ The property '#/' of type object did not match one or more of the required schemas in schema",
            code: '100', status: '422' },
          { title: "#/ The property '#/' did not contain a required property of 'primaryCaregiver'", code: '100',
            status: '422' },
          { title: "#/ The property '#/' did not contain a required property of 'secondaryCaregiverOne'", code: '100',
            status: '422' }
        ]

        expect(res_body['errors']).to be_present
        expect(res_body['errors'].size).to eq(expected_errors.size)

        expected_errors.each_with_index do |expected_error, index|
          actual_error = res_body['errors'][index]
          expect(actual_error['title']).to include(expected_error[:title])
          expect(actual_error['code']).to eq(expected_error[:code])
          expect(actual_error['status']).to eq(expected_error[:status])
        end
      end
    end

    context 'when an unexpected error' do
      let(:body) { { caregivers_assistance_claim: { form: valid_form_data } }.to_json }
      let(:claim) { build(:caregivers_assistance_claim, form: valid_form_data) }
      let(:error_message) { 'Some unexpected error' }

      before do
        allow(claim).to receive(:valid?).and_raise(StandardError.new(error_message))
      end

      it 'logs the error and re-raises it' do
        expect(Rails.logger).to receive(:debug).with(
          'CaregiverAssistanceClaim: error submitting claim',
          { saved_claim_guid: claim.guid, error: kind_of(StandardError) }
        )

        subject
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'POST /v0/caregivers_assistance_claims/download_pdf' do
    subject do
      post('/v0/caregivers_assistance_claims/download_pdf', params: body, headers:)
    end

    let(:endpoint) { '/v0/caregivers_assistance_claims/download_pdf' }
    let(:response_pdf) { Rails.root.join 'tmp', 'pdfs', '10-10CG_from_response.pdf' }
    let(:expected_pdf) { Rails.root.join 'spec', 'fixtures', 'pdf_fill', '10-10CG', 'unsigned', 'simple.pdf' }

    let(:form_data) { get_fixture('pdf_fill/10-10CG/simple').to_json }
    let(:claim) { build(:caregivers_assistance_claim, form: form_data) }
    let(:body) { { caregivers_assistance_claim: { form: form_data } }.to_json }

    after do
      FileUtils.rm_f(response_pdf)
    end

    it 'returns a completed PDF', run_at: '2017-07-25 00:00:00 -0400' do
      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        form: form_data
      ).and_return(
        claim
      )

      expect(SecureRandom).to receive(:uuid).and_return('saved-claim-guid')
      expect(SecureRandom).to receive(:uuid).and_return('file-name-uuid')
      expect_any_instance_of(Form1010cg::Auditor).to receive(:record).with(:pdf_download)

      subject

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

    it 'ensures the tmp file is deleted when send_data fails', run_at: '2017-07-25 00:00:00 -0400' do
      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        form: form_data
      ).and_return(claim)

      allow_any_instance_of(ApplicationController).to receive(:send_data).and_raise(StandardError, 'send_data failed')

      expect(SecureRandom).to receive(:uuid).and_return('saved-claim-guid')
      expect(SecureRandom).to receive(:uuid).and_return('file-name-uuid')
      expect_any_instance_of(Form1010cg::Auditor).to receive(:record).with(:pdf_download)

      subject

      expect(response).to have_http_status(:internal_server_error)
      expect(
        File.exist?('tmp/pdfs/10-10CG_file-name-uuid.pdf')
      ).to eq(false)
    end

    it 'ensures the tmp file is deleted when fill_form fails', run_at: '2017-07-25 00:00:00 -0400' do
      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        form: form_data
      ).and_return(claim)

      allow(PdfFill::Filler).to receive(:fill_form).and_raise(StandardError, 'error filling form')

      expect(SecureRandom).to receive(:uuid).and_return('saved-claim-guid')
      expect(SecureRandom).to receive(:uuid).and_return('file-name-uuid')

      expect_any_instance_of(ApplicationController).not_to receive(:send_data)

      expect(File).not_to receive(:delete)

      subject

      expect(response).to have_http_status(:internal_server_error)

      expect(
        File.exist?('tmp/pdfs/10-10CG_file-name-uuid.pdf')
      ).to eq(false)
    end
  end

  describe 'GET /v0/caregivers_assistance_claims/facilities' do
    subject do
      get('/v0/caregivers_assistance_claims/facilities', params:, headers:)
    end

    let(:headers) do
      {
        'ACCEPT' => 'application/json',
        'CONTENT_TYPE' => 'application/json'
      }
    end

    let(:params) do
      {
        'zip' => '90210',
        'state' => 'CA',
        'lat' => '34.0522',
        'long' => '-118.2437',
        'radius' => '50',
        'visn' => '1',
        'type' => '1',
        'mobile' => '1',
        'page' => '1',
        'per_page' => '10',
        'facilityIds' => 'vha_123,vha_456',
        'services' => ['1'],
        'bbox' => ['2']
      }
    end

    let(:mock_facility_response) do
      {
        'data' => [
          { 'id' => 'vha_123', 'attributes' => { 'name' => 'Facility 1' } },
          { 'id' => 'vha_456', 'attributes' => { 'name' => 'Facility 2' } }
        ]
      }
    end
    let(:lighthouse_service) { double('Lighthouse::Facilities::V1::Client') }

    before do
      allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(lighthouse_service)
      allow(lighthouse_service).to receive(:get_paginated_facilities).and_return(mock_facility_response)
    end

    it 'returns the response as JSON' do
      subject

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(mock_facility_response.to_json)
    end

    it 'calls the Lighthouse facilities service with the permitted params' do
      subject

      expected_params = ActionController::Parameters.new(params).permit!

      expect(lighthouse_service).to have_received(:get_paginated_facilities)
        .with(expected_params)
    end
  end
end
