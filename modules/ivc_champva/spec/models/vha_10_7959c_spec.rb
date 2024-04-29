# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959c do
  let(:data) do
    {
      'applicants' => {
        'full_name' => { 'first' => 'John', 'middle' => 'P', 'last' => 'Doe' },
        'ssn_or_tin' => '123456789',
        'address' => { 'country' => 'USA', 'postal_code' => '12345' }
      },
      'form_number' => '10-7959C',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha107959c) { described_class.new(data) }

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha107959c.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranMiddleName' => 'P',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959C',
        'businessLine' => 'CMP'
      )
    end
  end

  describe '#method_missing' do
    context 'when method is missing' do
      it 'returns the arguments passed to it' do
        args = %w[arg1 arg2]
        expect(IvcChampva::VHA107959c.new('data').handle_attachments(args)).to eq(args)
      end
    end
  end
end
