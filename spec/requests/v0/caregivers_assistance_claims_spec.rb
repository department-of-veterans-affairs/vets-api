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
