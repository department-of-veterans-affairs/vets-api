# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::S3::SubmissionArchiveBuilder do
  let(:form_id) { '21-10210' }
  let(:form_data) { File.read("modules/simple_forms_api/spec/fixtures/form_json/vba_#{form_id.gsub('-', '_')}.json") }
  let(:submission) { create(:form_submission, :pending, form_type: form_id, form_data:) }
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
  let(:archive_builder_instance) { described_class.new(benefits_intake_uuid:) }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
    allow_any_instance_of(described_class).to receive(:assign_instance_variables).and_call_original
  end

  describe '#initialize' do
    subject(:new) { archive_builder_instance }

    let(:defaults) do
      {
        attachments: nil,
        benefits_intake_uuid:,
        file_path: nil,
        include_json_archive: true,
        include_manifest: true,
        include_text_archive: true,
        metadata: nil,
        submission: nil
      }
    end

    it { is_expected.to have_received(:assign_instance_variables).with(defaults) } # rubocop:disable RSpec/SubjectStub

    context 'when initialized with a valid benefits_intake_uuid' do
      let(:archive_builder_instance) { described_class.new(benefits_intake_uuid:) }

      it 'successfully completes initialization' do
        expect { new }.not_to raise_exception
      end
    end

    context 'when initialized with valid file_path, attachments, and metadata' do
      let(:file_path) { 'modules/simple_forms_api/spec/fixtures/pdfs/vba_20_10207-completed.pdf' }
      let(:attachments) { [] }
      let(:metadata) do
        {
          veteranFirstName: 'John',
          veteranLastName: 'Veteran',
          fileNumber: '222773333',
          zipCode: '12345',
          source: 'VA Platform Digital Forms',
          docType: '21-10210',
          businessLine: 'CMP'
        }
      end
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

    let(:temp_file_path) { Rails.root.join("tmp/#{benefits_intake_uuid}-random-letters-n-numbers/").to_s }

    context 'when properly initialized' do
      it 'completes successfully' do
        expect(run).to eq(temp_file_path)
      end
    end
  end
end
