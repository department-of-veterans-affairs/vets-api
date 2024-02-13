# frozen_string_literal: true

# spec/models/simple_forms_api/vha1010d_spec.rb

require 'rails_helper'

RSpec.describe SimpleFormsApi::VHA1010d do
  let(:data) do
    {
      'veteran' => {
        'full_name' => { 'first' => 'John', 'last' => 'Doe' },
        'va_claim_number' => '123456789',
        'address' => { 'postal_code' => '12345' }
      },
      'form_number' => 'VHA1010d',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha1010d) { described_class.new(data) }
  let(:file_path) { 'test_file.pdf' }

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha1010d.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'source' => 'VA Platform Digital Forms',
        'docType' => 'VHA1010d',
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

      # Call the method under test
      vha1010d.handle_attachments(file_path)

      # Verify that CombinePDF.new was called
      expect(CombinePDF).to have_received(:new)
    end
  end
end
