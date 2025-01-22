# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/upload_supplemental_document_service'
require 'lighthouse/service_exception'

RSpec.describe BenefitsDocuments::Form526::UploadSupplementalDocumentService do
  subject { described_class }

  let(:file_body) { File.read(fixture_file_upload('doctors-note.pdf', 'application/pdf')) }

  before do
    # NOTE: to re-record the VCR cassettes for these tests:
    # 1. Comment out the bottom line of this block stubbing the token
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

  context 'with a valid participant_id and claim_id' do
    # NOTE: claim_id and participant_id are specific to the Lighthouse Sandbox environment
    # To re-record new VCR cassettes for these tests, requesting new ids from Lighthouse may be required
    let(:lighthouse_document) do
      build(
        :lighthouse_document,
        claim_id: '600453005',
        participant_id: '600076281',
        document_type: 'L023',
        file_name: 'doctors-note.pdf'
      )
    end

    it 'submits the document to Lighthouse' do
      VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_form_526_document_upload_200') do
        response = subject.call(file_body, lighthouse_document)

        expect(response.status).to eq(200)
        expect(response.body.dig('data', 'success')).to be(true)
      end
    end
  end

  context 'with an invalid particpant_id and claim_id' do
    let(:lighthouse_document) do
      build(
        :lighthouse_document,
        claim_id: '',
        participant_id: '',
        document_type: 'L023',
        file_name: 'doctors-note.pdf'
      )
    end

    it 'logs the error via Lighthouse::ServiceException and does not swallow the exception' do
      VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_form_526_document_upload_400') do
        expect(Lighthouse::ServiceException).to receive(:send_error).with(
          an_instance_of(Faraday::BadRequestError),
          'benefits_documents/form526/upload_supplemental_document_service',
          nil,
          'services/benefits-documents/v1/documents'
        ).and_raise(Common::Exceptions::BadRequest)

        expect { subject.call(file_body, lighthouse_document) }.to raise_error(Common::Exceptions::BadRequest)
      end
    end
  end

  describe 'Lighthouse::ServiceException handling' do
    # Lighthouse::ServiceException can either raise an error or return an error object,
    # so we need to account for both cases
    context 'when the service exception class returns an error object' do
      before do
        allow(Lighthouse::ServiceException).to receive(:send_error)
          .and_return(Faraday::BadRequestError)
      end

      it 're-raises the error' do
        expect do
          subject.call(file_body, LighthouseDocument.new)
        end.to raise_error(Faraday::BadRequestError)
      end
    end

    context 'when the service exception class raises an exception' do
      before do
        allow(Lighthouse::ServiceException).to receive(:send_error)
          .and_raise(Faraday::BadRequestError)
      end

      it 'the exception gets raised' do
        expect do
          subject.call(file_body, LighthouseDocument.new)
        end.to raise_error(Faraday::BadRequestError)
      end
    end
  end
end
