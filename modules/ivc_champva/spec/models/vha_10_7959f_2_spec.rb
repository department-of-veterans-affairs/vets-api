# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959f2 do
  let(:data) do
    {
      'primary_contact_info' => {
        'name' => {
          'first' => 'Veteran',
          'last' => 'Surname'
        },
        'email' => 'email@address.com'
      },
      'veteran' => {
        'full_name' => { 'first' => 'John', 'middle' => 'P', 'last' => 'Doe' },
        'va_claim_number' => '123456789',
        'mailing_address' => { 'country' => 'USA', 'postal_code' => '12345' }
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
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959F-2',
        'businessLine' => 'CMP',
        'primary_contact_info' => {
          'name' => {
            'first' => 'Veteran',
            'last' => 'Surname'
          },
          'email' => 'email@address.com'
        }
      )
    end
  end
end
