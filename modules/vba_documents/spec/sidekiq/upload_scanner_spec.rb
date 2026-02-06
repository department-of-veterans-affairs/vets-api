# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UploadScanner, type: :job do
  let(:upload) { create(:upload_submission) }
  let(:evidence_upload) { create(:upload_submission, consumer_name: 'appeals_api_sc_evidence_submission') }

  before do
    s3_client = instance_double(Aws::S3::Resource)
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
    @s3_bucket = instance_double(Aws::S3::Bucket)
    @s3_object = instance_double(Aws::S3::Object)
    allow(s3_client).to receive(:bucket).and_return(@s3_bucket)
    allow(Rails.logger).to receive(:info)
  end

  describe '#perform' do
    context 'when the object has been uploaded to s3' do
      before do
        expect(@s3_bucket).to receive(:object).with(upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(true)
      end

      it 'logs that processing has started' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          log_message = 'VBADocuments: Started processing UploadSubmission from S3'
          log_details = { 'job' => described_class.name }.merge(upload.as_json)

          described_class.new.perform

          expect(Rails.logger).to have_received(:info).with(log_message, log_details)
        end
      end

      it 'spawns processor jobs and updates the submission status' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
          expect(processor).to receive(:perform_async).with(upload.guid, caller: described_class.name)

          described_class.new.perform

          expect(upload.reload.status).to eq('uploaded')
        end
      end

      it 'logs that the upload status progressed to "uploaded"' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          described_class.new.perform

          log_message = 'VBADocuments: UploadSubmission progressed to "uploaded" status'
          log_details = { 'job' => described_class.name }.merge(upload.reload.as_json)

          expect(Rails.logger).to have_received(:info).with(log_message, log_details)
        end
      end

      it 'does not expire the submission' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
          expect(processor).to receive(:perform_async).with(upload.guid, caller: described_class.name)

          Timecop.travel(25.minutes.from_now) do
            described_class.new.perform

            expect(upload.reload.status).to eq('uploaded')
          end
        end
      end
    end

    context 'when the object has not been uploaded to s3' do
      before do
        expect(@s3_bucket).to receive(:object).with(upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(false)
      end

      it 'does not process the submission' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
          expect(processor).not_to receive(:perform_async).with(upload.guid)

          described_class.new.perform

          expect(upload.reload.status).to eq('pending')
        end
      end

      it 'expires the submission if created more than 20 minutes ago' do
        with_settings(Settings.vba_documents.s3, enabled: true) do
          processor = class_double(VBADocuments::UploadProcessor).as_stubbed_const
          expect(processor).not_to receive(:perform_async).with(upload.guid)

          Timecop.travel(25.minutes.from_now) do
            described_class.new.perform

            expect(upload.reload.status).to eq('expired')
          end
        end
      end
    end

    context 'when the submission is an appeal evidence upload' do
      before do
        expect(@s3_bucket).to receive(:object).with(evidence_upload.guid).and_return(@s3_object)
        expect(@s3_object).to receive(:exists?).and_return(true)
      end

      context 'and the delay evidence feature flag is enabled' do
        before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

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
        before { Flipper.disable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

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
