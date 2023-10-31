# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form_526_lighthouse_documents_service'
require 'lighthouse/benefits_documents/configuration'
require 'lighthouse/benefits_documents/service'

RSpec.describe BenefitsDocuments::Form526LighthouseDocumentsService do
  # Hardcoded ids corresponding to a valid claim id/file number combination in staging
  # These are subject to change and may need to be updated if VCR cassettes for this test are re-recorded
  let(:staging_user_submitted_claim_id) { '600423040' }
  let(:staging_user_file_number) { '796378881' }

  let(:submission) do
    create(
      :form526_submission,
      submitted_claim_id: staging_user_submitted_claim_id
    )
  end

  let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }

  let!(:test_object) do
    class Foo
      include BenefitsDocuments::Form526LighthouseDocumentsService
    end.new
  end

  before do
    allow_any_instance_of(BenefitsDocuments::Service).to receive(:file_number).and_return(staging_user_file_number)

    # NOTE: to re-record the VCR cassettes for these tests:
    # 1. Comment out the line below stubbing the token
    # 2. Ensure you have both a valid Lighthouse client_id and rsa_key in your config/settings/test.local.yml:
    # lighthouse:
    #   auth:
    #     ccg:
    #       client_id: <MY CLIENT ID>
    #        rsa_key: <MY RSA KEY PATH>
    # To generate the above credentials refer to this tutorial:
    # https://developer.va.gov/explore/api/benefits-documents/client-credentials
    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return('abcd1234')
  end

  describe '#upload_lighthouse_document' do
    it 'Returns a success response' do
      VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_form_526_document_upload_200') do
        response = test_object.upload_lighthouse_document(file_body, 'doctors-note.pdf', submission, 'L023')

        expect(response.status).to eq(200)
        expect(response.body.dig('data', 'success')).to eq(true)
      end
    end
  end
end
