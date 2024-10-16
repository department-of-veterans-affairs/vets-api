# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/configuration/vff_config'

RSpec.describe SimpleFormsApi::FormRemediation::SubmissionArchive do
  include SimpleFormsApi::FormRemediation::FileUtilities

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
  let(:new_submission_instance) { instance_double(SimpleFormsApi::FormRemediation::SubmissionRemediationData) }
  let(:hydrated_submission_instance) do
    instance_double(
      SimpleFormsApi::FormRemediation::SubmissionRemediationData, submission:, file_path:, attachments:, metadata:
    )
  end
  let(:config) { SimpleFormsApi::FormRemediation::Configuration::VffConfig.new }
  let(:submission_archive_instance) { described_class.new(id: benefits_intake_uuid, config:) }
  let(:temp_file_path) { Rails.root.join('tmp', 'random-letters-n-numbers-archive').to_s }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
    allow(SimpleFormsApi::FormRemediation::SubmissionRemediationData).to(
      receive(:new).and_return(new_submission_instance)
    )
    allow(new_submission_instance).to receive_messages(hydrate!: hydrated_submission_instance)
    allow(File).to receive_messages(write: true, directory?: true)
    allow(CSV).to receive(:open).and_return(true)
    allow(FileUtils).to receive(:mkdir_p).and_return(true)
    allow(submission_archive_instance).to receive(:zip_directory!) do |parent_dir, temp_dir, filename|
      s3_dir = build_path(:dir, parent_dir, 'remediation')
      s3_file_path = build_path(:file, s3_dir, filename, ext: '.zip')
      build_local_path_from_s3(s3_dir, s3_file_path, temp_dir)
    end
  end

  describe '#initialize' do
    subject(:new) { submission_archive_instance }

    context 'when initialized with a valid benefits_intake_uuid' do
      it 'successfully completes initialization' do
        expect { new }.not_to raise_exception
      end
    end

    context 'when initialized with valid hydrated submission data' do
      let(:submission_archive_instance) do
        described_class.new(config:, submission:, file_path:, attachments:, metadata:)
      end

      it 'successfully completes initialization' do
        expect { new }.not_to raise_exception
      end
    end

    context 'when no id is passed' do
      it 'raises an exception' do
        expect do
          described_class.new(id: nil, config:)
        end.to raise_exception(RuntimeError, 'No benefits_intake_uuid was provided')
      end
    end

    context 'when no config is passed' do
      it 'raises an exception' do
        expect do
          described_class.new(id: benefits_intake_uuid, config: nil)
        end.to raise_exception(NoMethodError, "undefined method `handle_error' for nil")
      end
    end
  end

  describe '#build!' do
    subject(:build_archive) { submission_archive_instance.build! }

    let(:zip_file_path) { "#{temp_file_path}/#{submission_file_path}.zip" }

    before { build_archive }

    context 'when properly initialized' do
      it 'builds the zip path correctly' do
        expect(build_archive[0]).to include(zip_file_path)
      end

      it 'builds the manifest entry correctly' do
        expect(build_archive[1]).to eq(
          [
            submission.created_at,
            form_type,
            benefits_intake_uuid,
            metadata['fileNumber'],
            metadata['veteranFirstName'],
            metadata['veteranLastName']
          ]
        )
      end

      it 'writes the submission pdf file' do
        expect(File).to have_received(:write).with(
          "#{temp_file_path}/#{submission_file_path}.pdf", a_string_starting_with('%PDF')
        )
      end

      it 'writes the attachment files' do
        attachments.each_with_index do |_, i|
          expect(File).to have_received(:write).with(
            "#{temp_file_path}/attachment_#{i + 1}__#{submission_file_path}.pdf", a_string_starting_with('%PDF')
          )
        end
      end

      it 'zips the directory' do
        expect(submission_archive_instance).to have_received(:zip_directory!).with(
          config.parent_dir,
          a_string_including('/tmp/random-letters-n-numbers-archive/'),
          a_string_including(submission_file_path)
        )
      end
    end
  end
end
