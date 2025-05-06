# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::UploadedDocumentService do
  let(:user) { create(:evss_user, :loa3) }

  describe '#get_documents' do
    context 'with a valid participant id' do
      it 'returns a list of uploaded documents' do
        VCR.use_cassette('bgs/uploaded_document_service/uploaded_document_data') do
          service = BGS::UploadedDocumentService.new(user)
          response = service.get_documents
          expect(response[0][:bnft_claim_id]).to eq('600174355')
        end
      end
    end

    context 'with an invalid participant id' do
      it 'returns an error' do
        VCR.use_cassette('bgs/uploaded_document_service/bad_participant_id') do
          allow(user).to receive(:participant_id).and_return('11111111111')
          service = BGS::UploadedDocumentService.new(user)
          response = service.get_documents
          expect(response).to be_empty
        end
      end
    end
  end
end
