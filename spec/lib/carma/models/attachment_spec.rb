# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Models::Attachment, type: :model do
  describe '::DOCUMENT_TYPES' do
    it 'has two document_types' do
      expect(described_class::DOCUMENT_TYPES[:_10_10cg]).to eq('10-10CG')
      expect(described_class::DOCUMENT_TYPES[:poa]).to eq('POA')
    end
  end

  describe '::new' do
    it 'accepts :carma_case_id, :title, :file_path, :document_date, :document_type' do
      attachment_data = {
        carma_case_id: 'aB935000000A9GoCAK',
        title: '10-10CG_John_Doe_03-30-2020',
        file_path: 'tmp/pdfs/10-10CG_123456.pdf',
        document_date: DateTime.now.to_date,
        document_type: described_class::DOCUMENT_TYPES[:_10_10cg]
      }

      subject = described_class.new(attachment_data)

      expect(subject.carma_case_id).to eq(attachment_data[:carma_case_id])
      expect(subject.title).to eq(attachment_data[:title])
      expect(subject.file_path).to eq(attachment_data[:file_path])
      expect(subject.document_date).to eq(attachment_data[:document_date])
      expect(subject.document_type).to eq(attachment_data[:document_type])
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
    it 'is accessible' do
      value = '10-10CG_John_Doe_03-30-2020'

      subject.title = value
      expect(subject.title).to eq(value)
    end
  end

  describe '#file_path' do
    it 'is accessible' do
      value = 'tmp/pdfs/10-10CG_123456.pdf'

      subject.file_path = value
      expect(subject.file_path).to eq(value)
    end
  end

  describe '#document_date' do
    it 'is accessible' do
      value = DateTime.now.to_date

      subject.document_date = value
      expect(subject.document_date).to eq(value)
    end
  end

  describe '#document_type' do
    it 'is accessible' do
      value = described_class::DOCUMENT_TYPES[:_10_10cg]

      subject.document_type = value
      expect(subject.document_type).to eq('10-10CG')

      value = described_class::DOCUMENT_TYPES[:poa]

      subject.document_type = value
      expect(subject.document_type).to eq('POA')
    end
  end

  describe '#to_request_payload' do
    it 'generates a request payload' do
      attachment_data = {
        carma_case_id: 'aB935000000A9GoCAK',
        title: '10-10CG_John_Doe_03-30-2020',
        file_path: 'tmp/pdfs/10-10CG_123456.pdf',
        document_date: DateTime.now.to_date,
        document_type: described_class::DOCUMENT_TYPES[:_10_10cg]
      }

      attachment = described_class.new(attachment_data)

      expect(File).to receive(:read).with(attachment_data[:file_path]).and_return(:FILE_CONTENTS)
      expect(Base64).to receive(:encode64).with(:FILE_CONTENTS).and_return('<FILE_CONTENTS>')

      expect(attachment.to_request_payload).to eq(
        {
          'attributes' => {
            'type' => 'ContentVersion',
            'referenceId' => '1010CG'
          },
          'Title' => attachment_data[:title],
          'PathOnClient' => attachment_data[:file_path],
          'CARMA_Document_Type__c' => attachment_data[:document_type],
          'CARMA_Document_Date__c' => attachment_data[:document_date].to_s,
          'FirstPublishLocationId' => attachment_data[:carma_case_id],
          'VersionData' => '<FILE_CONTENTS>'
        }
      )
    end
  end
end
