# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959f1 do
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
        'ssn' => '123456789',
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
  let(:file_path) { 'vha_10_7959f_1-tmp.pdf' }
  let(:uuid) { SecureRandom.uuid }
  let(:instance) { IvcChampva::VHA107959f1.new(data) }

  before do
    allow(instance).to receive_messages(uuid:, get_attachments: [])
  end

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha107959f1.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranMiddleName' => 'P',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'ssn_or_tin' => '123456789',
        'zipCode' => '12345',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959F-1',
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

  describe '#handle_attachments' do
    it 'renames the file and returns the new file path' do
      allow(File).to receive(:rename)
      result = instance.handle_attachments(file_path)
      expect(result).to eq(["#{uuid}_vha_10_7959f_1-tmp.pdf"])
    end
  end
end
