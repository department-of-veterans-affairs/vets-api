# frozen_string_literal: true

require 'rails_helper'
require 'zero_silent_failures/manual_remediation/saved_claim'

RSpec.describe ZeroSilentFailures::ManualRemediation::SavedClaim do
  let(:fake_claim) { build(:fake_saved_claim) }
  let(:submission) { build(:form_submission, :failure, form_type: fake_claim.form_id) }
  let(:attachment) { build(:persistent_attachment) }

  let(:fake_pdf_path) { 'fake_pdf_path' }
  let(:stamper) { instance_double(PDFUtilities::DatestampPdf) }

  let(:s3_resource) { double('Aws::S3::Resource') }
  let(:s3_bucket) { double('s3_resource.bucket') }
  let(:s3_object) { double('s3_bucket.object') }

  let(:remediation) { described_class.new(fake_claim.id) }

  before do
    allow(attachment).to receive(:to_pdf).and_return(fake_pdf_path)
    fake_claim.persistent_attachments << attachment
    fake_claim.form_submissions << submission
    allow(fake_claim).to receive(:to_pdf).and_return(fake_pdf_path)
    allow(SavedClaim).to receive(:find).and_return(fake_claim)

    # ensure that the testing zip file is deleted
    allow(Settings).to receive(:vsp_environment).and_return 'production'

    allow(stamper).to receive(:run).and_return(fake_pdf_path)
    allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(stamper)

    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
    allow(s3_resource).to receive(:bucket).and_return(s3_bucket)
    allow(s3_bucket).to receive(:object).and_return(s3_object)
  end

  describe '#run' do
    it 'completes manual remediation process successfully' do
      expect(stamper).to receive(:run).twice

      # metadata.json, claim.pdf, attachment.pdf
      expect_any_instance_of(Zip::File).to receive(:add).exactly(3).times

      expect(s3_object).to receive(:upload_file).with(remediation.zipfile, content_type: Mime[:zip].to_s)
      expect(s3_object).to receive(:presigned_url)

      fs_ids = [submission.id]
      expect(FormSubmissionAttempt).to receive(:where).with(form_submission_id: fs_ids, aasm_state: 'failure')

      remediation.run
    end
  end

  context 'error handling coverage' do
    describe '#stamp_pdf' do
      it 'returns the original pdf_path' do
        allow(stamper).to receive(:run).and_raise(StandardError)

        path = remediation.send('stamp_pdf', fake_pdf_path, Time.zone.now)
        expect(path).to equal(fake_pdf_path)
      end
    end

    describe '#zip_files' do
      it 'raises the error' do
        remediation.instance_variable_set(:@files, [fake_pdf_path])
        allow_any_instance_of(Zip::File).to receive(:add).and_raise(StandardError)

        expect(Rails.logger).to receive(:error)

        expect { remediation.send('zip_files') }.to raise_exception(StandardError)
      end
    end

    describe '#aws_upload_zipfile' do
      it 'raises the error' do
        allow(s3_object).to receive(:upload_file).and_raise(StandardError)

        expect(s3_object).not_to receive(:presigned_url)
        expect(Rails.logger).to receive(:error)

        expect { remediation.send('aws_upload_zipfile') }.to raise_exception(StandardError)
      end
    end
  end
end
