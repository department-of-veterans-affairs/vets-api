# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/spec/support/vba_document_fixtures'

describe VBADocuments::UploadFile, type: :model do
  include VBADocuments::Fixtures

  it 'can upload and purge from storage' do
    upload_model = VBADocuments::UploadFile.new
    base_64 = File.read(get_fixture('base_64'))
    upload_model.multipart.attach(io: StringIO.new(base_64), filename: upload_model.guid)
    upload_model.save!
    upload_model.parse_and_upload!
    expect(upload_model).to be_uploaded
    expect(upload_model.use_active_storage).to be_truthy
    upload_model.remove_from_storage
    expect(upload_model).not_to be_uploaded
  end

  it 'does not instantiatiate on UploadSubmission' do
    upload_model = VBADocuments::UploadSubmission.new
    upload_model.save!
    expect { VBADocuments::UploadFile.find_by(guid: upload_model.guid) }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
