# frozen_string_literal: true

require 'rails_helper'
require 'lib/carma/models/processable_model_spec'

RSpec.describe CARMA::Models::Attachment, type: :model do
  describe '::DOCUMENT_TYPES' do
    it 'has two DOCUMENT_TYPE' do
      expect(described_class::DOCUMENT_TYPES['10-10CG']).to eq('10-10CG')
      expect(described_class::DOCUMENT_TYPES['POA']).to eq('POA')
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
      expect(subject.document_date).to eq('02-27-2020')
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
      expect(subject.document_type).to eq('POA')
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
            'referenceId' => '1010CG'
          },
          'Title' => '10-10CG_Jane_Doe_02-27-2020',
          'PathOnClient' => 'tmp/pdfs/10-10CG_123456.pdf',
          'CARMA_Document_Type__c' => '10-10CG',
          'CARMA_Document_Date__c' => '02-27-2020',
          'FirstPublishLocationId' => 'aB935000000A9GoCAK',
          'VersionData' => '<FILE_CONTENTS>'
        }
      )
    end
  end

  describe '#submit!' do
    let(:subject) do
      described_class.new(
        carma_case_id: 'aB935000000A9GoCAK',
        veteran_name: { first: 'Jane', last: 'Doe' },
        file_path: 'tmp/pdfs/10-10CG_123456.pdf',
        document_type: described_class::DOCUMENT_TYPES['10-10CG']
      )
    end

    context 'when already submitted' do
      it 'raises an exception' do
        subject.submitted_at = DateTime.now.iso8601
        expect { subject.submit! }.to raise_error('This attachment has already been submitted to CARMA')
      end
    end

    context 'when Flipper enabled' do
      it 'submits to CARMA, updates :submitted_at, and sets the :response', run_at: '2020-02-27T15:12:05Z' do
        expect(Flipper).to receive(:enabled?).with(:stub_carma_responses).and_return(true)

        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:to_request_payload).and_return(:REQUEST_PAYLOAD)
        # rubocop:enable RSpec/SubjectStub

        expect_any_instance_of(CARMA::Client::Client).not_to receive(:create_attachment)
        expect_any_instance_of(CARMA::Client::Client).to receive(:create_attachment_stub).with(
          :REQUEST_PAYLOAD
        ).and_return(
          :CARMA_CLIENT_RESPONSE
        )

        expect(subject.submitted_at).to eq(nil)
        expect(subject.submitted?).to eq(false)

        subject.submit!

        expect(subject.submitted_at).to eq('2020-02-27T15:12:05Z')
        expect(subject.submitted?).to eq(true)
      end
    end

    context 'when Flipper disabled' do
      it 'returns a hardcoded CARMA response and updates :submitted_at', run_at: '2020-02-27T15:12:05Z' do
        expect(Flipper).to receive(:enabled?).with(:stub_carma_responses).and_return(false)

        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:to_request_payload).and_return(:REQUEST_PAYLOAD)
        # rubocop:enable RSpec/SubjectStub

        expect_any_instance_of(CARMA::Client::Client).not_to receive(:create_attachment_stub)
        expect_any_instance_of(CARMA::Client::Client).to receive(:create_attachment).with(
          :REQUEST_PAYLOAD
        ).and_return(
          :CARMA_CLIENT_RESPONSE
        )

        expect(subject.submitted_at).to eq(nil)
        expect(subject.submitted?).to eq(false)

        subject.submit!

        expect(subject.submitted_at).to eq('2020-02-27T15:12:05Z')
        expect(subject.submitted?).to eq(true)
      end
    end
  end
end
