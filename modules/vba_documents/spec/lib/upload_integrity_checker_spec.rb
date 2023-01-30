# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/upload_integrity_checker'
require 'vba_documents/multipart_parser'
require_relative '../support/vba_document_fixtures'

RSpec.describe VBADocuments::UploadIntegrityChecker do
  include VBADocuments::Fixtures

  subject { described_class.new(upload_submission, parts) }

  let(:file_path) { get_fixture('valid_multipart_pdf.blob').path }
  let(:parts) { VBADocuments::MultipartParser.parse(file_path) }
  let(:original_checksum) { '8024913596ef5d1969dfbb84a68adca98eb19fec817921cfb8366e441ad28667' }
  let(:upload_submission) do
    create(:upload_submission,
           metadata: {
             'base64_encoded' => false,
             'original_checksum' => original_checksum
           })
  end

  describe '#check_integrity' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      # rubocop:disable RSpec/SubjectStub
      allow(subject).to receive(:log_message_to_sentry)
      # rubocop:enable RSpec/SubjectStub
    end

    context 'when the submission has a content file and metadata only' do
      before do
        subject.check_integrity
        upload_submission.reload
      end

      it 'generates a checksum that matches the original checksum and saves it to the submission metadata' do
        expect(upload_submission.metadata['recalculated_checksum']).to eql(original_checksum)
      end

      it 'saves a boolean for whether the checksums match to the submission metadata' do
        expect(upload_submission.metadata['checksums_match']).to be(true)
      end
    end

    context 'when the submission has a content file, attachment, and metadata' do
      let(:file_path) { get_fixture('valid_multipart_pdf_attachments.blob').path }
      let(:original_checksum) { '7f911935bfa1f3f850294c613c08333ee38025dbc8315b260e395a0b88e3f603' }
      let(:upload_submission) do
        create(:upload_submission,
               metadata: {
                 'base64_encoded' => false,
                 'original_checksum' => original_checksum
               })
      end

      before do
        subject.check_integrity
        upload_submission.reload
      end

      it 'generates a checksum that matches the original checksum and saves it to the submission metadata' do
        expect(upload_submission.metadata['recalculated_checksum']).to eql(original_checksum)
      end

      it 'saves a boolean for whether the checksums match to the submission metadata' do
        expect(upload_submission.metadata['checksums_match']).to be(true)
      end
    end

    context 'when the submission is base64 encoded' do
      let(:file_path) { get_fixture('base_64_with_attachment').path }
      let(:original_checksum) { 'abab9603090f71a4b3aa48b5ecdc5dd9b33e1fb2189a702b2699baf6e24dd7af' }
      let(:upload_submission) do
        create(:upload_submission,
               metadata: {
                 'base64_encoded' => true,
                 'original_checksum' => original_checksum
               })
      end

      before do
        subject.check_integrity
        upload_submission.reload
      end

      it 'generates a checksum that matches the original checksum and saves it to the submission metadata' do
        expect(upload_submission.metadata['recalculated_checksum']).to eql(original_checksum)
      end

      it 'saves a boolean for whether the checksums match to the submission metadata' do
        expect(upload_submission.metadata['checksums_match']).to be(true)
      end
    end

    context 'when the generated file does not match the original file' do
      let(:original_checksum) { 'some_other_checksum' }
      let(:warning_message) { "#{described_class} failed for upload" }
      let(:exception_message) { "Checksums don't match!" }

      let(:logger_message) { "#{warning_message}, guid: #{upload_submission.guid}" }
      let(:sentry_message) { "#{warning_message}: #{exception_message}" }

      it 'logs to Rails logger, log level: warn' do
        subject.check_integrity
        expect(Rails.logger).to have_received(:warn).with(logger_message, exception_message)
      end

      # rubocop:disable RSpec/SubjectStub
      it 'logs a warning to Sentry' do
        subject.check_integrity
        expect(subject).to have_received(:log_message_to_sentry).with(sentry_message, :warning)
      end
      # rubocop:enable RSpec/SubjectStub
    end

    it 'logs when the process is starting' do
      log_message = "#{described_class} starting, guid: #{upload_submission.guid}"
      subject.check_integrity
      expect(Rails.logger).to have_received(:info).with(log_message)
    end

    it 'logs when the process is complete' do
      log_message = "#{described_class} complete, guid: #{upload_submission.guid}"
      subject.check_integrity
      expect(Rails.logger).to have_received(:info).with(log_message)
    end
  end
end
