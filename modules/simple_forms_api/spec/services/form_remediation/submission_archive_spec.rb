# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/error'
require 'simple_forms_api/form_remediation/configuration/vff_config'

RSpec.describe SimpleFormsApi::FormRemediation::SubmissionArchive do
  include SimpleFormsApi::FormRemediation::FileUtilities

  let(:form_type) { '20-10207' }
  let(:fixtures_path) { 'modules/simple_forms_api/spec/fixtures' }
  let(:form_data) do
    Rails.root.join(fixtures_path, 'form_json', 'vba_20_10207_with_supporting_documents.json').read
  end
  let(:file_path) { Rails.root.join(fixtures_path, 'pdfs', 'vba_20_10207-completed.pdf') }
  let(:attachments) { Array.new(5) { fixture_file_upload('doctors-note.pdf', 'application/pdf').path } }
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:) }
  let(:benefits_intake_uuid) { submission&.latest_attempt&.benefits_intake_uuid }
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
  let(:submission_file_path) { unique_file_name(form_type, benefits_intake_uuid) }
  let(:new_submission_instance) { instance_double(SimpleFormsApi::FormRemediation::SubmissionRemediationData) }
  let(:hydrated_submission_instance) do
    instance_double(SimpleFormsApi::FormRemediation::SubmissionRemediationData, submission:, file_path:, attachments:,
                                                                                metadata:)
  end
  let(:config) { SimpleFormsApi::FormRemediation::Configuration::VffConfig.new }
  let(:temp_file_path) { Rails.root.join('tmp', 'random-letters-n-numbers-archive').to_s }
  let(:default_args) { { id: benefits_intake_uuid, config:, type: } }
  let(:hydrated_submission_args) { default_args.merge(submission:, file_path:, attachments:, metadata:) }

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
  end

  %i[submission remediation].each do |archive_type|
    describe "when archiving a #{archive_type}" do
      let(:type) { archive_type }

      describe '#initialize' do
        subject(:archive_instance) { described_class.new(**args) }

        context 'when initialized with a valid id' do
          let(:args) { default_args }

          it 'successfully completes initialization' do
            expect { archive_instance }.not_to raise_exception
          end

          context 'when no id is passed' do
            let(:benefits_intake_uuid) { nil }
            let(:error_message) { 'No benefits_intake_uuid was provided' }

            it 'raises an exception' do
              expect do
                archive_instance
              end.to raise_exception(SimpleFormsApi::FormRemediation::Error, a_string_including(error_message))
            end
          end

          context 'when no config is passed' do
            let(:config) { nil }

            it 'raises an exception' do
              expect { archive_instance }.to(
                raise_exception(SimpleFormsApi::FormRemediation::NoConfigurationError, 'No configuration was provided')
              )
            end
          end
        end

        context 'when initialized with valid hydrated submission data' do
          let(:args) { hydrated_submission_args }

          it 'successfully completes initialization' do
            expect { archive_instance }.not_to raise_exception
          end

          context 'when no submission is passed' do
            let(:submission) { nil }
            let(:benefits_intake_uuid) { 'random-letters-n-numbers' }

            it 'successfully completes initialization' do
              expect { archive_instance }.not_to raise_exception
            end

            context 'when no id is passed' do
              let(:benefits_intake_uuid) { nil }
              let(:error_message) { 'No benefits_intake_uuid was provided' }

              it 'raises an exception' do
                expect { archive_instance }.to(
                  raise_exception(SimpleFormsApi::FormRemediation::Error, a_string_including(error_message))
                )
              end
            end
          end
        end
      end

      describe '#build!' do
        let(:file_name) { "#{temp_file_path}/#{submission_file_path}.#{type == :remediation ? 'zip' : 'pdf'}" }

        before do
          allow(archive_instance).to receive(:zip_directory!) do |parent_dir, temp_dir, filename|
            s3_dir = build_path(:dir, parent_dir, 'remediation')
            s3_file_path = build_path(:file, s3_dir, filename, ext: '.zip')
            build_local_path_from_s3(s3_dir, s3_file_path, temp_dir)
          end
        end

        shared_examples 'successfully built submission archive' do
          it 'builds the file path correctly' do
            expect(build_archive.first).to include(file_name)
          end

          it 'builds the manifest entry correctly' do
            expect(build_archive.second).to eq(
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
            build_archive
            expect(File).to have_received(:write).with(
              "#{temp_file_path}/#{submission_file_path}.pdf", a_string_starting_with('%PDF')
            )
          end

          it 'writes the attachment files' do
            build_archive
            attachments.each_with_index do |_, i|
              expect(File).to have_received(:write).with(
                "#{temp_file_path}/attachment_#{i + 1}__#{submission_file_path}.pdf", a_string_starting_with('%PDF')
              )
            end
          end

          it 'zips the directory when necessary' do
            build_archive
            if type == :submission
              expect(archive_instance).not_to have_received(:zip_directory!)
            else
              expect(archive_instance).to have_received(:zip_directory!).with(
                config.parent_dir, "#{temp_file_path}/", submission_file_path
              )
            end
          end

          context 'when the attachment file cannot be found' do
            let(:attachments) { ['non-existent-file.pdf'] }
            let(:error_message) { 'Attachment file not found: non-existent-file.pdf' }

            it 'raises an exception' do
              expect { build_archive }.to raise_exception(
                SimpleFormsApi::FormRemediation::Error, a_string_including(error_message)
              )
            end
          end
        end

        context 'when initialized with a valid id' do
          subject(:build_archive) { archive_instance.build! }

          let(:archive_instance) { described_class.new(**default_args) }

          include_examples 'successfully built submission archive'
        end

        context 'when initialized with valid submission data' do
          subject(:build_archive) { archive_instance.build! }

          let(:archive_instance) { described_class.new(**hydrated_submission_args) }

          include_examples 'successfully built submission archive'
        end
      end

      describe '#retrieval_data' do
        subject(:retrieval_data) { archive_instance.retrieval_data }

        let(:archive_instance) { described_class.new(**hydrated_submission_args) }
        let(:file_name) { "#{temp_file_path}/#{submission_file_path}.#{type == :remediation ? 'zip' : 'pdf'}" }

        it 'returns the correct archive path and manifest row' do
          expect(retrieval_data.first).to include(file_name)
          expect(retrieval_data.second).to eq(
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
      end
    end
  end
end
