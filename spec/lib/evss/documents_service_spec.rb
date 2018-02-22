# frozen_string_literal: true

require 'rails_helper'
require 'evss/documents_service'
require 'evss/auth_headers'

describe EVSS::DocumentsService do
  let(:current_user) { FactoryBot.create(:evss_user) }
  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end
  let(:document_data) do
    EVSSClaimDocument.new(
      evss_claim_id: 600_118_851,
      file_name: 'doctors-note.pdf',
      tracked_item_id: nil,
      document_type: 'L023'
    )
  end

  subject { described_class.new(auth_headers) }

  context 'with headers' do
    it 'should upload documents', run_at: 'Fri, 05 Jan 2018 00:12:00 GMT' do
      VCR.use_cassette('evss/documents/upload', VCR::MATCH_EVERYTHING) do
        demo_file_name = "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf"
        File.open(demo_file_name, 'rb') do |f|
          response = subject.upload(f, document_data)
          expect(response).to be_success
        end
      end
    end
  end
end
