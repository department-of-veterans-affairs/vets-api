# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'

RSpec.describe VBADocuments::UploadRemover, type: :job do
  include VBADocuments::Fixtures

  before do
    @objstore = instance_double(VBADocuments::ObjectStore)
    @s3_object = instance_double(Aws::S3::Object)
    allow(VBADocuments::ObjectStore).to receive(:new).and_return(@objstore)
    allow(@objstore).to receive(:object).and_return(@s3_object)
    allow(@s3_object).to receive(:exists?).and_return(true)
  end

  describe '#perform' do
    describe 'when the record is older than 10 days' do
      let(:upload) { create(:upload_submission, status: 'received', created_at: 11.days.ago) }

      it 'deletes the s3 object' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          expect(@objstore).to receive(:delete).with(upload.guid)
          described_class.new.perform
        end
      end

      it 'sets s3_deleted to true' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          allow(@objstore).to receive(:delete).with(upload.guid)
          described_class.new.perform
          upload.reload
          expect(upload.s3_deleted).to be_truthy
        end
      end
    end

    describe 'when record status is error' do
      let(:upload) { create(:upload_submission, status: 'error', created_at: 11.days.ago) }

      it 'deletes the s3 object' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          expect(@objstore).to receive(:delete).with(upload.guid)
          described_class.new.perform
        end
      end
    end

    describe 'when the record is not 3 days old' do
      let(:upload) { create(:upload_submission, status: 'received') }

      it 'does nothing' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          expect(@objstore).not_to receive(:delete).with(upload.guid)
          described_class.new.perform
          upload.reload
          expect(upload.s3_deleted).to be_falsy
        end
      end
    end

    describe 'when a record was manually removed from s3' do
      let(:upload_manually_removed) do
        create(:upload_submission_manually_removed, status: 'received', s3_deleted: false,
                                                    created_at: 11.days.ago)
      end
      let(:upload_old) { create(:upload_submission, status: 'received', created_at: 12.days.ago) }

      it 'still removes other records older than 10 days' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          s3_object_manually_removed = instance_double(Aws::S3::Object)
          s3_object_old = instance_double(Aws::S3::Object)
          allow(@objstore).to receive(:object).with(upload_manually_removed.guid).and_return(s3_object_manually_removed)
          allow(s3_object_manually_removed).to receive(:exists?).and_return(false)
          allow(@objstore).to receive(:object).with(upload_old.guid).and_return(s3_object_old)
          allow(s3_object_old).to receive(:exists?).and_return(true)
          expect(@objstore).to receive(:delete).with(upload_old.guid)
          expect(@objstore).to receive(:delete).with(upload_manually_removed.guid)
          described_class.new.perform
          upload_old.reload
          expect(upload_old.s3_deleted).to be_truthy
        end
      end
    end
  end
end
