# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Evss::Document do
  subject { described_class.new(user_uuid: '1234', auth_headers: auth_headers, document: upload_doc) }
  let(:file) do
    File.open(Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf'))
  end

  let(:auth_headers) do
    EVSS::AuthHeaders.new(FactoryGirl.build(:loa3_user)).to_h
  end

  let(:upload_doc) do
    EVSSClaimDocument.new(
      evss_claim_id: 189_625,
      file_name: 'doctors-note.pdf',
      tracked_item_id: 33,
      document_type: 'L023'
    ).to_serializable_hash
  end

  before(:each) do
    Sidekiq::Testing.inline!
  end
  after(:each) do
    Sidekiq::Testing.fake!
  end

  it 'runs through and uploads the file' do
    VCR.use_cassette('evss/documents/upload') do
      subject.start!(file)
    end
  end
end
