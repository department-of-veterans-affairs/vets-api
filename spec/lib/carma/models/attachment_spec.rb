# frozen_string_literal: true

require 'rails_helper'
require 'carma/models/attachment'

RSpec.describe CARMA::Models::Attachment, type: :model do
  describe '::DOCUMENT_TYPES' do
    it 'has two DOCUMENT_TYPE' do
      expect(described_class::DOCUMENT_TYPES['10-10CG']).to eq('10-10CG')
      expect(described_class::DOCUMENT_TYPES['POA']).to eq('Legal Representative')
    end
  end

  describe '::new', run_at: '2020-02-27T11:12:05-04:00' do
    it 'accepts :carma_case_id, :veteran_name, :file_path, :document_type' do
      attachment_data = {
        carma_case_id: 'aB935000000A9GoCAK',
        veteran_name: { first: 'John', last: 'Doe' },
        file_path: 'tmp/pdfs/10-10CG_123456.pdf',
        document_type: described_class::DOCUMENT_TYPES['10-10CG']
      }

      subject = described_class.new(attachment_data)

      expect(subject.carma_case_id).to eq('aB935000000A9GoCAK')
      expect(subject.veteran_name[:first]).to eq('John')
      expect(subject.veteran_name[:last]).to eq('Doe')
      expect(subject.file_path).to eq('tmp/pdfs/10-10CG_123456.pdf')
      expect(subject.document_type).to eq('10-10CG')
      expect(subject.document_date.to_s).to eq(Time.now.in_time_zone('Eastern Time (US & Canada)').to_date.to_s)
    end
  end

  describe '#carma_case_id' do
    it 'is accessible' do
      value = 'aB935000000A9GoCAK'

      subject.carma_case_id = value
      expect(subject.carma_case_id).to eq(value)
    end
  end

  describe '#title' do
    it 'builds a formatted title for the document', run_at: '2020-02-27T11:12:05-04:00' do
      subject = described_class.new(
        carma_case_id: 'aB935000000A9GoCAK',
        veteran_name: { first: 'Jane', last: 'Doe' },
        file_path: 'tmp/pdfs/10-10CG_123456.pdf',
        document_type: described_class::DOCUMENT_TYPES['10-10CG']
      )

      expect(subject.title).to eq('10-10CG_Jane_Doe_02-27-2020')
    end
  end

  describe '#file_path' do
    it 'is accessible' do
      value = 'tmp/pdfs/10-10CG_123456.pdf'

      subject.file_path = value
      expect(subject.file_path).to eq(value)
    end
  end

  describe '#document_type' do
    it 'is accessible' do
      value = described_class::DOCUMENT_TYPES['10-10CG']

      subject.document_type = value
      expect(subject.document_type).to eq('10-10CG')

      value = described_class::DOCUMENT_TYPES['POA']

      subject.document_type = value
      expect(subject.document_type).to eq('Legal Representative')
    end
  end

  describe '#document_date' do
    it 'is accessible' do
      value = Time.now.in_time_zone('Eastern Time (US & Canada)').to_date

      subject.document_date = value
      expect(subject.document_date).to eq(value)
    end
  end

  describe '#reference_id' do
    it 'returns the :document_type without a hyphen' do
      subject.document_type = '10-10CG'
      expect(subject.reference_id).to eq('1010CG')

      subject.document_type = 'POA'
      expect(subject.reference_id).to eq('POA')
    end
  end

  describe '#to_request_payload' do
    it 'generates a request payload', run_at: '2020-02-27T11:12:05-04:00' do
      attachment_data = {
        carma_case_id: 'aB935000000A9GoCAK',
        veteran_name: { first: 'Jane', last: 'Doe' },
        file_path: 'tmp/pdfs/10-10CG_123456.pdf',
        document_type: described_class::DOCUMENT_TYPES['10-10CG']
      }

      attachment = described_class.new(attachment_data)

      expect(File).to receive(:read).with(attachment_data[:file_path]).and_return(:FILE_CONTENTS)
      expect(Base64).to receive(:encode64).with(:FILE_CONTENTS).and_return('<FILE_CONTENTS>')

      expect(attachment.to_request_payload).to eq(
        {
          'attributes' => {
            'type' => 'ContentVersion',
            'referenceId' => '1010CG' # No hyphen for 10-10CG Type Documents
          },
          'Title' => '10-10CG_Jane_Doe_02-27-2020', # Date format MM-DD-YYYY
          'PathOnClient' => '10-10CG_123456.pdf', # File name only (no path)
          'CARMA_Document_Type__c' => '10-10CG',
          'CARMA_Document_Date__c' => '2020-02-27', # Date format YYYY-MM-DD
          'FirstPublishLocationId' => 'aB935000000A9GoCAK', # The CARMA Case ID
          'VersionData' => '<FILE_CONTENTS>' # Base64 encoded contents
        }
      )
    end
  end
end
