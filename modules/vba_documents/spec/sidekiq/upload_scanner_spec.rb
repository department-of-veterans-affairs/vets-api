# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UploadScanner, type: :job do
  before do
    s3_client = instance_double(Aws::S3::Resource)
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
    @s3_bucket = instance_double(Aws::S3::Bucket)
    @s3_object = instance_double(Aws::S3::Object)
    allow(s3_client).to receive(:bucket).and_return(@s3_bucket)
  end

  let(:upload) { FactoryBot.create(:upload_submission) }
  let(:evidence_upload) { FactoryBot.create(:upload_submission, consumer_name: 'appeals_api') }

  describe '#perform' do
    it 'spawns processor jobs and updates state' do
      with_settings(Settings.vba_documents.s3, enabled: true) do
        expect(@s3_bucket).to receive(:object).with(upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(true)
        processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
        expect(processor).to receive(:perform_async).with(upload.guid, caller: described_class.name)
        described_class.new.perform
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).to eq('uploaded')
      end
    end

    it 'skips objects that have not been uploaded' do
      with_settings(Settings.vba_documents.s3, enabled: true) do
        expect(@s3_bucket).to receive(:object).with(upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(false)
        processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
        expect(processor).not_to receive(:perform_async).with(upload.guid)
        described_class.new.perform
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).to eq('pending')
      end
    end

    it 'expires objects for which no upload has occurred' do
      with_settings(Settings.vba_documents.s3, enabled: true) do
        expect(@s3_bucket).to receive(:object).with(upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(false)
        processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
        expect(processor).not_to receive(:perform_async).with(upload.guid)
        Timecop.travel(Time.zone.now + 25.minutes) do
          described_class.new.perform
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.status).to eq('expired')
        end
      end
    end

    it 'does not expire objects for which upload has occurred' do
      with_settings(Settings.vba_documents.s3, enabled: true) do
        expect(@s3_bucket).to receive(:object).with(upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(true)
        processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
        expect(processor).to receive(:perform_async).with(upload.guid, caller: described_class.name)
        Timecop.travel(Time.zone.now + 25.minutes) do
          described_class.new.perform
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.status).to eq('uploaded')
        end
      end
    end

    context 'when the submission is an appeal evidence upload' do
      before do
        expect(@s3_bucket).to receive(:object).with(evidence_upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(true)
      end

      context 'and the delay evidence feature flag is enabled' do
        before { Flipper.enable(:decision_review_delay_evidence) }

        it 'updates the submission status to "uploaded"' do
          with_settings(Settings.vba_documents.s3, enabled: true) do
            described_class.new.perform
          end

          expect(evidence_upload.reload.status).to eq('uploaded')
        end

        it 'does not trigger the UploadProcessor job' do
          processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
          expect(processor).not_to receive(:perform_async)

          with_settings(Settings.vba_documents.s3, enabled: true) do
            described_class.new.perform
          end
        end
      end

      context 'and the delay evidence feature flag is disabled' do
        before { Flipper.disable(:decision_review_delay_evidence) }

        it 'updates the submission status to "uploaded"' do
          with_settings(Settings.vba_documents.s3, enabled: true) do
            described_class.new.perform
          end

          expect(evidence_upload.reload.status).to eq('uploaded')
        end

        it 'triggers the UploadProcessor job' do
          processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
          expect(processor).to receive(:perform_async)

          with_settings(Settings.vba_documents.s3, enabled: true) do
            described_class.new.perform
          end
        end
      end
    end
  end
end
