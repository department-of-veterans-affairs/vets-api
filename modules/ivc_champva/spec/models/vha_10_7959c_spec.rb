# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959c do
  let(:data) do
    {
      'primary_contact_info' => {
        'name' => {
          'first' => 'Veteran',
          'last' => 'Surname'
        },
        'email' => false
      },
      'applicant_name' => {
        'first' => 'John',
        'middle' => 'P',
        'last' => 'Doe'
      },
      'applicant_address' => {
        'country' => 'USA',
        'postal_code' => '12345'
      },
      'applicant_ssn' => '123456789',
      'form_number' => '10-7959C',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha107959c) { described_class.new(data) }
  let(:file_path) { 'vha_10_7959c-tmp.pdf' }
  let(:uuid) { SecureRandom.uuid }
  let(:instance) { IvcChampva::VHA107959c.new(data) }

  before do
    allow(instance).to receive_messages(uuid:, get_attachments: [])
  end

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

  describe '#method_missing' do
    it 'returns the method name and arguments' do
      result = instance.some_missing_method('arg1', 'arg2')
      expect(result).to eq({ method: :some_missing_method, args: %w[arg1 arg2] })
    end
  end

  describe '#handle_attachments' do
    it 'renames the file and returns the new file path' do
      allow(File).to receive(:rename)
      result = instance.handle_attachments(file_path)
      expect(result).to eq(["#{uuid}_vha_10_7959c-tmp.pdf"])
    end
  end
end
