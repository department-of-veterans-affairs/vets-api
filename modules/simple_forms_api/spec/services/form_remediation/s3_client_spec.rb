# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/configuration/vff_config'

RSpec.describe SimpleFormsApi::FormRemediation::S3Client do
  let(:form_type) { '20-10207' }
  let(:fixtures_path) { 'modules/simple_forms_api/spec/fixtures' }
  let(:form_data) { Rails.root.join(fixtures_path, 'form_json', 'vba_20_10207_with_supporting_documents.json').read }
  let(:file_path) { Rails.root.join(fixtures_path, 'pdfs', 'vba_20_10207-completed.pdf') }
  let(:attachments) { Array.new(5) { fixture_file_upload('doctors-note.pdf', 'application/pdf').path } }
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:) }
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
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
  let(:submission_archive_instance) { instance_double(SimpleFormsApi::FormRemediation::SubmissionArchive) }
  let(:temp_file_path) { Rails.root.join('tmp', 'random-letters-n-numbers-archive').to_s }
  let(:submission_file_path) do
    [Time.zone.today.strftime('%-m.%d.%y'), 'form', form_type, 'vagov', benefits_intake_uuid].join('_')
  end
  let(:uploader) { instance_double(SimpleFormsApi::FormRemediation::Uploader) }
  let(:carrier_wave_file) { instance_double(CarrierWave::Storage::Fog::File) }
  let(:s3_file) { instance_double(Aws::S3::Object) }
  let(:manifest_entry) do
    [
      submission.created_at,
      form_type,
      benefits_intake_uuid,
      metadata['fileNumber'],
      metadata['veteranFirstName'],
      metadata['veteranLastName']
    ]
  end
  let(:config) { SimpleFormsApi::FormRemediation::Configuration::VffConfig.new }

  before do
    allow(FileUtils).to receive(:mkdir_p).and_return(true)
    allow(File).to receive(:directory?).and_return(true)
    allow(CSV).to receive(:open).and_return(true)
    allow(SimpleFormsApi::FormRemediation::SubmissionArchive).to(receive(:new).and_return(submission_archive_instance))
    allow(submission_archive_instance).to receive(:build!).and_return(
      ["#{temp_file_path}/", manifest_entry]
    )
    allow(SimpleFormsApi::FormRemediation::Uploader).to receive_messages(new: uploader)
    allow(uploader).to receive_messages(get_s3_link: '/s3_url/stuff.pdf', get_s3_file: s3_file)
    allow(uploader).to receive_messages(store!: carrier_wave_file)
    allow(Rails.logger).to receive(:info).and_call_original
    allow(Rails.logger).to receive(:error).and_call_original
  end

  describe '#initialize' do
    subject(:new) { described_class.new(id: benefits_intake_uuid, config:) }

    context 'when initialized with a valid benefits_intake_uuid' do
      it 'successfully completes initialization' do
        expect { new }.not_to raise_exception
      end
    end
  end

  describe '#upload' do
    subject(:upload) { instance.upload }

    let(:instance) { described_class.new(id: benefits_intake_uuid, config:) }

    context 'when no errors occur' do
      it 'logs notifications' do
        upload
        expect(Rails.logger).to have_received(:info).with(
          { message: "Uploading remediation: #{benefits_intake_uuid} to S3 bucket" }
        )
        expect(Rails.logger).to have_received(:info).with(
          { message: "Initialized S3Client for remediation with ID: #{benefits_intake_uuid}" }
        )
        expect(Rails.logger).to have_received(:info).with(
          { message: "Cleaning up path: #{temp_file_path}/" }
        )
      end

      it 'returns the s3 directory' do
        expect(upload).to eq('/s3_url/stuff.pdf')
      end

      context 'when a different parent_dir is provided' do
        let(:instance) { described_class.new(id: benefits_intake_uuid, config:) }

        it 'returns the s3 directory' do
          expect(upload).to eq('/s3_url/stuff.pdf')
        end
      end
    end

    context 'when an error occurs' do
      before do
        allow(File).to receive(:directory?).and_return(false)
      end

      let(:instance) { described_class.new(id: benefits_intake_uuid, config:) }

      it 'raises the error' do
        expect { upload }.to raise_exception(Errno::ENOENT)
      end
    end
  end
end
