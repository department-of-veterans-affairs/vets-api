# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Documents::Service do
  let(:current_user) { FactoryGirl.create(:loa3_user) }
  let(:document_data) do
    EVSSClaimDocument.new(
      evss_claim_id: 189_625,
      file_name: 'doctors-note.pdf',
      tracked_item_id: 33,
      document_type: 'L023'
    )
  end

  subject { described_class.new(current_user) }

  context 'with headers' do
    it 'should upload documents' do
      VCR.use_cassette('evss/documents/upload') do
        demo_file_name = "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf"
        File.open(demo_file_name, 'rb') do |f|
          response = subject.upload(f, document_data)
          expect(response).to be_success
        end
      end
    end
  end
end
