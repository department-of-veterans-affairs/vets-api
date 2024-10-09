# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::S3::SubmissionArchiveBuilder do
  let(:form_type) { '20-10207' }
  let(:fixtures_path) { 'modules/simple_forms_api/spec/fixtures' }
  let(:form_data) { Rails.root.join(fixtures_path, 'form_json', 'vba_20_10207_with_supporting_documents.json').read }
  let(:file_path) { Rails.root.join(fixtures_path, 'pdfs', 'vba_20_10207-completed.pdf') }
  let(:attachments) { Array.new(5) { fixture_file_upload('doctors-note.pdf', 'application/pdf').path } }
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:) }
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
  let(:metadata) do
    {
      veteranFirstName: 'John',
      veteranLastName: 'Veteran',
      fileNumber: '321540987',
      zipCode: '12345',
      source: 'VA Platform Digital Forms',
      docType: '20-10207',
      businessLine: 'CMP'
    }
  end
  let(:submission_file_path) do
    [Time.zone.today.strftime('%-m.%d.%y'), 'form', form_type, 'vagov', benefits_intake_uuid].join('_')
  end
  let(:submission_builder) { OpenStruct.new(submission:, file_path:, attachments:, metadata:) }
  let(:archive_builder_instance) { described_class.new(benefits_intake_uuid:) }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
    allow(SimpleFormsApi::S3::SubmissionBuilder).to receive(:new).and_return(submission_builder)
    allow(File).to receive(:write).and_return(true)
    allow(CSV).to receive(:open).and_return(true)
    allow(FileUtils).to receive(:mkdir_p).and_return(true)
  end

  describe '#initialize' do
    subject(:new) { archive_builder_instance }

    context 'when initialized with a valid benefits_intake_uuid' do
      it 'successfully completes initialization' do
        expect { new }.not_to raise_exception
      end
    end

    context 'when initialized with valid hydrated submission data' do
      let(:archive_builder_instance) { described_class.new(submission:, file_path:, attachments:, metadata:) }

      it 'successfully completes initialization' do
        expect { new }.not_to raise_exception
      end
    end

    context 'when no valid parameters are passed' do
      let(:archive_builder_instance) { described_class.new(benefits_intake_uuid: nil) }

      it 'raises an exception' do
        expect { new }.to raise_exception('No benefits_intake_uuid was provided')
      end
    end
  end

  describe '#run' do
    subject(:run) { archive_builder_instance.run }

    let(:temp_file_path) { Rails.root.join("tmp/#{benefits_intake_uuid}-random-letters-n-numbers-archive/").to_s }

    context 'when properly initialized' do
      it 'completes successfully' do
        expect(run).to eq([temp_file_path, submission, submission_file_path, metadata])
      end

      it 'writes the submission pdf file' do
        run
        expect(File).to have_received(:write).with(
          "#{temp_file_path}#{submission_file_path}.pdf", a_string_starting_with('%PDF')
        )
      end

      it 'writes the attachment files' do
        run
        attachments.each_with_index do |_, i|
          expect(File).to have_received(:write).with(
            "#{temp_file_path}attachment_#{i + 1}__#{submission_file_path}.pdf", a_string_starting_with('%PDF')
          )
        end
      end

      it 'writes the manifest file' do
        run
        expect(CSV).to have_received(:open).with("#{temp_file_path}manifest_#{submission_file_path}.csv", 'wb')
      end

      it 'writes the metadata json file' do
        run
        expect(File).to have_received(:write).with(
          "#{temp_file_path}metadata_#{submission_file_path}.json", metadata.to_json
        )
      end
    end
  end
end
