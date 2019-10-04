# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::ClaimUploader, type: :job do
  subject { described_class }

  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:supporting_document) do
    supporting_document = create(:supporting_document)
    supporting_document.set_file_data!(
      Rack::Test::UploadedFile.new(
        "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
      ),
      'docType',
      'description'
    )
    supporting_document.save!
    supporting_document
  end

  it 'submits succesfully' do
    expect do
      subject.perform_async(supporting_document.id)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'on successful call and deletes the file' do
    evss_service_stub = instance_double('EVSS::DocumentsService')
    allow(EVSS::DocumentsService).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:upload) { OpenStruct.new(response: 200) }

    subject.new.perform(supporting_document.id)
    supporting_document.reload
    expect(supporting_document.uploader.blank?).to eq(true)
  end
end
