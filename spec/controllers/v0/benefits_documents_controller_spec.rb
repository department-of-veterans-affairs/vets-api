# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/service'
require 'lighthouse/service_exception'

RSpec.describe V0::BenefitsDocumentsController, type: :controller do
  let(:user) { create(:user, :loa3, :accountable, uuid: '1234', icn: '123498767V234859') }

  before do
    sign_in_as(user)

    token = 'fake_access_token'

    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#create' do
    context 'when successful' do
      before do
        allow_any_instance_of(BenefitsDocuments::Service)
          .to receive(:queue_document_upload)
          .and_return({ jid: 12 })
      end

      it 'returns a status of 202 and the job ID' do
        file = Rack::Test::UploadedFile.new(Tempfile.new('banana.pdf'))

        post(:create, params: { file:, benefits_claim_id: 1, document_type: 'L015' })

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'when NOT successful' do
      it 'returns a 400 when the file parameter is missing' do
        post(:create, params: { benefits_claim_id: 1, document_type: 'L015' })

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns a 404 when unable to find the associated claim' do
        allow_any_instance_of(BenefitsDocuments::Service)
          .to receive(:queue_document_upload)
          .and_raise(Common::Exceptions::ResourceNotFound)

        file = Rack::Test::UploadedFile.new(Tempfile.new('banana.pdf'))

        post(:create, params: { file:, benefits_claim_id: 1, document_type: 'L015' })

        expect(response).to have_http_status(:not_found)
      end

      it 'returns a 422 when the document metadata is not valid' do
        file = Rack::Test::UploadedFile.new(Tempfile.new('banana.pdf'))

        post(:create, params: { file:, benefits_claim_id: 1, document_type: 'BANANA' })

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
