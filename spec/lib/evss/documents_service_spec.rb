# frozen_string_literal: true

require 'rails_helper'
require 'evss/documents_service'

describe EVSS::DocumentsService do
  subject { described_class.new(auth_headers) }

  let(:current_user) { create(:evss_user) }
  let(:auth_headers) { EVSS::AuthHeaders.new(current_user).to_h }
  let(:transaction_id) { auth_headers['va_eauth_service_transaction_id'] }

  let(:document_data) do
    EVSSClaimDocument.new(
      evss_claim_id: 600_118_851,
      file_name: 'doctors-note.pdf',
      tracked_item_id: nil,
      document_type: 'L023'
    )
  end

  context 'with headers' do
    it 'uploads documents', run_at: 'Fri, 05 Jan 2018 00:12:00 GMT' do
      VCR.use_cassette(
        'evss/documents/upload',
        erb: { transaction_id: },
        match_requests_on: VCR.all_matches
      ) do
        demo_file_name = Rails.root.join(*'/spec/fixtures/files/doctors-note.pdf'.split('/')).to_s
        File.open(demo_file_name, 'rb') do |f|
          response = subject.upload(f, document_data)
          expect(response).to be_success
        end
      end
    end

    context 'with headers' do
      it 'gets claim documents', run_at: 'Fri, 05 Jan 2018 00:12:00 GMT' do
        VCR.use_cassette(
          'evss/documents/get_claim_documents',
          match_requests_on: VCR.all_matches
        ) do
          response = subject.get_claim_documents(document_data.evss_claim_id)
          expect(response).to be_success
        end
      end
    end

    context 'with a backend service error' do
      it 'raises EVSSError' do
        VCR.use_cassette('evss/documents/upload_with_errors') do
          demo_file_name = Rails.root.join(*'/spec/fixtures/files/doctors-note.pdf'.split('/')).to_s
          File.open(demo_file_name, 'rb') do |f|
            expect { subject.upload(f, document_data) }.to raise_exception(EVSS::ErrorMiddleware::EVSSError)
          end
        end
      end
    end
  end
end
