# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Caregivers Assistance Claims' do
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
    let(:endpoint) { '/v0/caregivers_assistance_claims/download_pdf' }
    let(:response_pdf) { Rails.root.join 'tmp', 'pdfs', '10-10CG_from_response.pdf' }
    let(:expected_pdf) { Rails.root.join 'spec', 'fixtures', 'pdf_fill', '10-10CG', 'unsigned', 'simple.pdf' }

    after do
      File.delete(response_pdf) if File.exist?(response_pdf)
    end

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

      post(endpoint, params: body, headers:)

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
