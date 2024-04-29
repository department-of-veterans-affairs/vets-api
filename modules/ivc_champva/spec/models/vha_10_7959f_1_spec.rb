# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959f1 do
  let(:data) do
    {
      'veteran' => {
        'full_name' => { 'first' => 'John', 'middle' => 'P', 'last' => 'Doe' },
        'va_claim_number' => '123456789',
        'mailing_address' => { 'country' => 'USA', 'postal_code' => '12345' }
      },
      'form_number' => '10-7959F-1',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha107959f1) { described_class.new(data) }

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha107959f1.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranMiddleName' => 'P',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959F-1',
        'businessLine' => 'CMP'
      )
    end
  end

  describe '#method_missing' do
    context 'when method is missing' do
      it 'returns the arguments passed to it' do
        args = %w[arg1 arg2]
        expect(IvcChampva::VHA107959f1.new('data').handle_attachments(args)).to eq(args)
      end
    end
  end
end
