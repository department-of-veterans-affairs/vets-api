# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_submission_service'

RSpec.describe DebtsApi::V0::DigitalDisputeJob, type: :job do
  describe '#perform' do
    let(:user_data) do
      {
        'uuid' => '1234-5678',
        'ssn' => '111-22-3333',
        'participant_id' => '987654'
      }
    end

    let(:pdf_content) { '%PDF-1.4 fake pdf content here' }
    let(:base64_content) { Base64.strict_encode64(pdf_content) }

    let(:file_hash) do
      {
        'fileName' => 'test.pdf',
        'fileContents' => base64_content
      }
    end

    let(:metadata) { { some_key: 'some_value' } }

    it 'calls the service with decoded files and metadata' do
      service_instance = instance_double(DebtsApi::V0::DigitalDisputeSubmissionService)
      allow(DebtsApi::V0::DigitalDisputeSubmissionService).to receive(:new).and_return(service_instance)
      expect(service_instance).to receive(:call)

      described_class.new.perform(user_data, [file_hash], metadata)
    end

    it 'decodes the base64 file into an UploadedFile' do
      job = described_class.new
      decoded_file = job.send(:decoded_file, file_hash)

      expect(decoded_file).to be_an(ActionDispatch::Http::UploadedFile)
      expect(decoded_file.original_filename).to eq('test.pdf')
      expect(decoded_file.content_type).to eq('application/pdf')
      expect(decoded_file.read).to eq(pdf_content)
    end
  end
end
