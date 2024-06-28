# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959a do
  let(:data) do
    {
      'primary_contact_info' => {
        'name' => {
          'first' => 'Veteran',
          'last' => 'Surname'
        },
        'email' => false
      },
      'veteran' => {
        'full_name' => { 'first' => 'John', 'middle' => 'P', 'last' => 'Doe' },
        'va_claim_number' => '123456789',
        'address' => { 'country' => 'USA', 'postal_code' => '12345' }
      },
      'form_number' => '10-7959A',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha_10_7959a) { described_class.new(data) }

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha_10_7959a.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'zipCode' => '12345',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959A',
        'businessLine' => 'CMP',
        'primaryContactInfo' => {
          'name' => {
            'first' => 'Veteran',
            'last' => 'Surname'
          },
          'email' => false
        }
      )
    end
  end
end
