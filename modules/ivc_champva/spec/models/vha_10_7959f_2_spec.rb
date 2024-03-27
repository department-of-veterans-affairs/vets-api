# frozen_string_literal: true

require 'rails_helper'

folder_path = 'modules/ivc_champva/spec/fixtures/test_file/'
file_name = 'test_file.pdf'
file_path = File.join(folder_path, file_name)

RSpec.describe IvcChampva::VHA107959f2 do
  let(:data) do
    {
      'veteran' => {
        'full_name' => { 'first' => 'John', 'middle' => 'P', 'last' => 'Doe' },
        'va_claim_number' => '123456789',
        'mailing_address' => { 'postal_code' => '12345' }
      },
      'form_number' => '10-7959F-2',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha107959f2) { described_class.new(data) }

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha107959f2.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranMiddleName' => 'P',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959F-2',
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
      vha107959f2.handle_attachments(file_path)

      # Verify that CombinePDF.new was called
      expect(CombinePDF).to have_received(:new)
    end
  end
end
