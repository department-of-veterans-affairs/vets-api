# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::S3Service::SubmissionArchiver, type: :model do
  let(:submission_id) { 1 }
  let(:form_id) { '21-10210' }
  let(:form_data) { File.read('modules/simple_forms_api/spec/fixtures/form_json/vba_21_10210.json') }
  let(:submission) { create(:form_submission, :pending, form_type: form_id, form_data:) }
  let(:options) do
    {
      include_json_archive: true,
      include_text_archive: true,
      parent_dir: 'test-dir',
      quiet_pdf_failures: true,
      quiet_upload_failures: true,
      run_quiet: true
    }
  end
  let(:archive_submission) { described_class.new(submission_id:, **options) }

  before do
    allow(FormSubmission).to receive(:find).and_return(submission)
  end

  describe '#initialize' do
    it 'sets default values for instance variables' do
      expect(archive_submission.submission).to eq(submission)
      expect(archive_submission.parent_dir).to eq('test-dir')
      expect(archive_submission.include_json_archive).to be(true)
      expect(archive_submission.include_text_archive).to be(true)
      expect(archive_submission.quiet_pdf_failures).to be(true)
      expect(archive_submission.quiet_upload_failures).to be(true)
    end
  end

  describe '#run' do
    before do
      allow(archive_submission).to receive(:process_submission_files)
      allow(archive_submission).to receive(:output_directory_path).and_return('/some/path')
      allow(archive_submission).to receive(:log_info)
    end

    it 'logs the processing of the submission and calls process_submission_files' do
      expect(archive_submission).to receive(:log_info).with("Processing submission ID: #{submission.id}")
      expect(archive_submission).to receive(:process_submission_files)
      archive_submission.run
    end

    context 'when an error occurs' do
      before do
        allow(archive_submission).to receive(:process_submission_files).and_raise(StandardError, 'Processing error')
      end

      xit 'handles errors and logs them' do
        expect(archive_submission).to(
          receive(:handle_error).with(
            "Failed submission: #{submission.id}",
            instance_of(StandardError), submission_id: submission.id
          )
        )
        expect { archive_submission.run }.not_to raise_error
      end
    end
  end

  describe '#write_pdf' do
    before do
      allow(archive_submission).to receive(:generate_pdf_content).and_return(Base64.encode64('pdf content'))
      allow(archive_submission).to receive(:save_file_to_s3)
    end

    xit 'writes the PDF to S3' do
      expect(archive_submission).to receive(:save_file_to_s3).with(/form.pdf/, 'pdf content')
      archive_submission.run
    end

    context 'when an error occurs' do
      before do
        allow(archive_submission).to receive(:generate_pdf_content).and_raise(StandardError, 'PDF generation error')
      end

      it 'handles pdf generation errors based on quiet_pdf_failures' do
        expect(archive_submission).to receive(:write_pdf_error).with(instance_of(StandardError))
        expect { archive_submission.run }.not_to raise_error
      end
    end
  end

  describe '#write_as_json_archive' do
    before do
      allow(archive_submission).to receive(:save_file_to_s3)
      allow(archive_submission).to receive(:form_json).and_return({ key: 'value' })
    end

    it 'writes the JSON archive to S3' do
      expect(archive_submission).to receive(:save_file_to_s3).with(/form_text_archive.json/,
                                                                   JSON.pretty_generate({ key: 'value' }))
      archive_submission.run
    end
  end

  describe '#write_as_text_archive' do
    before do
      allow(archive_submission).to receive(:save_file_to_s3)
      allow(archive_submission).to receive(:form_text_archive).and_return({ key: 'value' })
    end

    it 'writes the text archive to S3' do
      expect(archive_submission).to receive(:save_file_to_s3).with(/form_text_archive.txt/, { key: 'value' }.to_json)
      archive_submission.run
    end
  end

  describe '#write_metadata' do
    before do
      allow(archive_submission).to receive(:save_file_to_s3)
      allow(archive_submission).to receive(:metadata).and_return({ key: 'value' })
    end

    xit 'writes metadata to S3' do
      expect(archive_submission).to receive(:save_file_to_s3).with(/metadata.json/, { key: 'value' }.to_json)
      archive_submission.run
    end
  end

  describe '#handle_error' do
    before do
      allow(archive_submission).to receive(:process_submission_files).and_return(error)
    end

    let(:error) { StandardError.new('some error') }

    xit 'logs the error and re-raises it' do
      expect(archive_submission).to receive(:log_error).with(
        "Failed submission: #{submission.id}", error, submission_id: submission.id
      )
      expect { archive_submission.run }.to raise_error(error)
    end
  end
end
