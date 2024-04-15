# frozen_string_literal: true

require 'rails_helper'

folder_path = 'modules/simple_forms_api/spec/fixtures/test_file/'
file_name = 'test_file.pdf'
file_path = File.join(folder_path, file_name)

RSpec.describe SimpleFormsApi::VHA1010d do
  let(:data) do
    {
      'veteran' => {
        'full_name' => { 'first' => 'John', 'last' => 'Doe' },
        'va_claim_number' => '123456789',
        'address' => { 'postal_code' => '12345' }
      },
      'form_number' => '10-10D',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha1010d) { described_class.new(data) }

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha1010d.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-10D',
        'businessLine' => 'CMP'
      )
    end
  end

  describe '#handle_attachments' do
    it 'calls CombinePDF.new' do
      # Stub the CombinePDF.new method to return a double that does not perform any actions
      allow(CombinePDF).to receive(:new).and_return(double('combined_pdf', save: nil))
      combined_pdf = CombinePDF.new
      p combined_pdf # Output to console using `p` for inspection

      # Stub the file operation
      allow(File).to receive(:exist?).with(file_path).and_return(true)
      allow(File).to receive(:open).with(file_path, 'rb')
      # Call the method under test
      vha1010d.handle_attachments(file_path)

      # Verify that CombinePDF.new was called
      expect(CombinePDF).to have_received(:new)
    end
  end
end
