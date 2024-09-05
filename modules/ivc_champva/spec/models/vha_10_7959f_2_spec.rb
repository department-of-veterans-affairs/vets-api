# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959f2 do
  let(:data) do
    {
      'form_number' => '10-7959F-2',
      'primary_contact_info' => {
        'name' => {
          'first' => 'Veteran',
          'last' => 'Surname'
        },
        'email' => 'email@address.com'
      },
      'veteran_full_name' => { 'first' => 'John', 'middle' => 'P', 'last' => 'Doe' },
      'veteran_social_security_number' => {
        'ssn' => '123123123',
        'va_file_number' => '123123123'
      },
      'veteran_address' => {
        'country' => 'USA',
        'street' => '123 Street Lane',
        'city' => 'Cityburg',
        'state' => 'AL',
        'postal_code' => '12312'
      },
      'supporting_docs' => [
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
        'fileNumber' => '123123123',
        'ssn_or_tin' => '123123123',
        'zipCode' => '12312',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959F-2',
        'businessLine' => 'CMP',
        'primaryContactInfo' => {
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
