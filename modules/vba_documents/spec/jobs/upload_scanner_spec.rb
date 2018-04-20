# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UploadScanner, type: :job do
  before(:each) do
    s3_client = instance_double(Aws::S3::Resource)
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
    @s3_bucket = instance_double(Aws::S3::Bucket)
    @s3_object = instance_double(Aws::S3::Object)
    allow(s3_client).to receive(:bucket).and_return(@s3_bucket)
  end

  describe '#perform' do
    let(:upload) { FactoryBot.create(:upload_submission) }

    it 'spawns processor jobs and updates state' do
      with_settings(Settings.vba_documents.s3, 'enabled': true) do
        expect(@s3_bucket).to receive(:object).with(upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(true)
        processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
        expect(processor).to receive(:perform_async).with(upload.guid)
        described_class.new.perform
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).to eq('uploaded')
      end
    end

    it 'skips objects that have not been uploaded' do
      with_settings(Settings.vba_documents.s3, 'enabled': true) do
        expect(@s3_bucket).to receive(:object).with(upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(false)
        processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
        expect(processor).not_to receive(:perform_async).with(upload.guid)
        described_class.new.perform
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).to eq('pending')
      end
    end
  end
end
