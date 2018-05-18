# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/object_store'
require 'vba_documents/upload_remover'

RSpec.describe VBADocuments::UploadRemover, type: :job do
  include VBADocuments::Fixtures

  before(:each) do
    @objstore = instance_double(VBADocuments::ObjectStore)
    @s3_object = instance_double(Aws::S3::Object)
    allow(VBADocuments::ObjectStore).to receive(:new).and_return(@objstore)
    allow(@objstore).to receive(:object).and_return(@s3_object)
    allow(@s3_object).to receive(:exists?).and_return(true)
  end

  describe '#perform' do
    describe 'when the record is older than 3 days' do
      let(:upload) { FactoryBot.create(:upload_submission, status: 'received', created_at: Time.zone.now - 4.days) }

      it 'should delete the s3 object' do
        with_settings(Settings.vba_documents.s3, 'enabled': true) do
          expect(@objstore).to receive(:delete).with(upload.guid)
          described_class.new.perform
        end
      end

      it 'should set s3_deleted to true' do
        with_settings(Settings.vba_documents.s3, 'enabled': true) do
          allow(@objstore).to receive(:delete).with(upload.guid)
          described_class.new.perform
          upload.reload
          expect(upload.s3_deleted).to be_truthy
        end
      end
    end

    describe 'when record status is error' do
      let(:upload) { FactoryBot.create(:upload_submission, status: 'error', created_at: Time.zone.now - 4.days) }

      it 'should delete the s3 object' do
        with_settings(Settings.vba_documents.s3, 'enabled': true) do
          expect(@objstore).to receive(:delete).with(upload.guid)
          described_class.new.perform
        end
      end
    end

    describe 'when the record is not 3 days old' do
      let(:upload) { FactoryBot.create(:upload_submission, status: 'received') }

      it 'should do nothing' do
        with_settings(Settings.vba_documents.s3, 'enabled': true) do
          expect(@object).to_not receive(:delete).with(upload.guid)
          described_class.new.perform
          upload.reload
          expect(upload.s3_deleted).to be_falsy
        end
      end
    end
  end
end
