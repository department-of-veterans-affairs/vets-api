# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/SubjectStub
RSpec.describe SimpleFormsApi::S3::SubmissionArchiver, skip: 'These are flaky, need to be fixed.' do
  let(:form_type) { '21-10210' }
  let(:form_data) { File.read("modules/simple_forms_api/spec/fixtures/form_json/vba_#{form_type.gsub('-', '_')}.json") }
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:) }
  let(:metadata) do
    {
      'veteranFirstName' => 'John',
      'veteranLastName' => 'Veteran',
      'fileNumber' => '222773333',
      'zipCode' => '12345',
      'source' => 'VA Platform Digital Forms',
      'docType' => form_type,
      'businessLine' => 'CMP'
    }
  end
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
  let(:randomness) { 'random-letters-n-numbers' }
  let(:file_path) { Rails.root.join("tmp/#{benefits_intake_uuid}-#{randomness}/").to_s }
  let(:archive) { OpenStruct.new(submission:, file_path:, attachments: [], metadata:) }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow(SecureRandom).to receive(:hex).and_return(randomness)
    allow_any_instance_of(described_class).to receive(:build_submission_archive).and_call_original
    allow_any_instance_of(described_class).to receive(:log_info).and_call_original
    allow_any_instance_of(described_class).to receive(:upload_temp_folder_to_s3).and_return('/things/stuff/')
    allow_any_instance_of(described_class).to receive(:cleanup).and_return(true)
    allow_any_instance_of(described_class).to receive(:generate_presigned_url).and_return('/s3_url/stuff.pdf')
    allow_any_instance_of(SimpleFormsApi::S3::SubmissionArchiveBuilder).to receive(:run).and_return(file_path)
  end

  describe '#initialize' do
    subject(:instance) { described_class.new(benefits_intake_uuid:) }

    it { is_expected.to have_received(:build_submission_archive) }
  end

  describe '#upload' do
    subject(:upload) { instance.upload }

    let(:instance) { described_class.new(benefits_intake_uuid:) }

    context 'when no errors occur' do
      it 'logs a notification upon starting' do
        upload
        log_message = "Uploading archive: #{benefits_intake_uuid} to S3 bucket"
        expect(instance).to have_received(:log_info).with(log_message)
      end

      it 'returns the s3 directory' do
        expect(upload).to eq('/s3_url/stuff.pdf')
      end

      context 'when a different parent_dir is provided' do
        let(:instance) { described_class.new(parent_dir: 'super-great-forms-team', benefits_intake_uuid:) }

        it 'returns the s3 directory' do
          expect(upload).to eq('/s3_url/stuff.pdf')
        end
      end
    end

    context 'when an error occurs' do
      before do
        allow(Dir).to receive(:glob).and_raise(StandardError, 'oopsy')
        allow(Rails.logger).to receive(:error).and_call_original
        allow(instance).to receive(:upload_temp_folder_to_s3).and_call_original
      end

      let(:instance) { described_class.new(benefits_intake_uuid:) }

      it 'raises the error' do
        expect { upload }.to raise_exception(StandardError, 'oopsy')
      end
    end
  end

  describe '#download' do
    subject(:download) { instance.download(type) }

    let(:instance) { described_class.new(benefits_intake_uuid:) }

    context 'submission' do
      before do
        allow(instance).to receive(:download_submission_from_s3).and_return('/s3_directory_path/submission.pdf')
      end

      let(:type) { :submission }

      context 'when no errors occur' do
        it 'logs a notification upon starting' do
          download
          log_message = "Downloading #{type}: #{benefits_intake_uuid} to temporary directory: #{file_path}"
          expect(instance).to have_received(:log_info).with(log_message)
        end

        it 'returns the s3 directory' do
          expect(download).to eq('/s3_directory_path/submission.pdf')
        end
      end

      context 'when an error occurs' do
        before do
          allow(Reports::Uploader).to receive(:new_s3_resource).and_raise(StandardError, 'oopsy')
          allow(Rails.logger).to receive(:error).and_call_original
          allow(instance).to receive(:download_submission_from_s3).and_call_original
        end

        let(:instance) { described_class.new(benefits_intake_uuid:) }

        it 'raises the error' do
          expect { download }.to raise_exception(StandardError, 'oopsy')
        end
      end
    end

    context 'archive' do
      before do
        allow(instance).to receive(:download_archive_from_s3).and_return('/s3_directory_path/')
      end

      let(:type) { :archive }

      context 'when no errors occur' do
        it 'logs a notification upon starting' do
          download
          log_message = "Downloading #{type}: #{benefits_intake_uuid} to temporary directory: #{file_path}"
          expect(instance).to have_received(:log_info).with(log_message)
        end

        it 'returns the s3 directory' do
          expect(download).to eq('/s3_directory_path/')
        end

        context 'when a different parent_dir is provided' do
          let(:instance) { described_class.new(parent_dir: 'super-great-forms-team', benefits_intake_uuid:) }

          it 'returns the s3 directory' do
            expect(download).to eq('/s3_directory_path/')
          end
        end
      end

      context 'when an error occurs' do
        before do
          allow(Reports::Uploader).to receive(:new_s3_resource).and_raise(StandardError, 'oopsy')
          allow(Rails.logger).to receive(:error).and_call_original
          allow(instance).to receive(:download_archive_from_s3).and_call_original
        end

        let(:instance) { described_class.new(benefits_intake_uuid:) }

        it 'raises the error' do
          expect { download }.to raise_exception(StandardError, 'oopsy')
        end
      end
    end
  end

  describe '#cleanup' # TODO: add this coverage in future PR
  describe '.fetch_presigned_url' # TODO: add this coverage in future PR
  describe '.fetch_s3_submission' # TODO: add this coverage in future PR
  describe '.fetch_s3_archive' # TODO: add this coverage in future PR
end
# rubocop:enable RSpec/SubjectStub
