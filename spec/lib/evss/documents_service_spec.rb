# frozen_string_literal: true
require 'rails_helper'
require_dependency 'evss/documents_service'
require_dependency 'evss/auth_headers'

describe EVSS::DocumentsService do
  let(:current_user) do
    User.sample_claimant
  end
  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  subject { described_class.new(auth_headers) }

  context 'with headers' do
    it 'should get claims' do
      VCR.use_cassette('evss/documents/all_documents') do
        response = subject.all_documents
        expect(response).to be_success
      end
    end

    it 'should upload documents' do
      VCR.use_cassette('evss/documents/upload') do
        demo_file_name = "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf"
        File.open(demo_file_name, 'rb') do |f|
          response = subject.upload('doctors-note.pdf', f, 189_625, 33)
          expect(response).to be_success
        end
      end
    end
  end
end
