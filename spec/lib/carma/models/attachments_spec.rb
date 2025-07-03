# frozen_string_literal: true

require 'rails_helper'
require 'carma/models/attachments'

RSpec.describe CARMA::Models::Attachments, type: :model do
  let(:subject) { described_class.new('aB935000000A9GoCAK', 'Jane', 'Doe') }

  describe '::new' do
    it 'requires a CARMA Case ID and Vetern\'s Name' do
      expect { described_class.new }.to raise_error ArgumentError, 'wrong number of arguments (given 0, expected 3)'
    end
  end

  describe '#all' do
    it 'is accessable' do
      expect(subject.all).to eq([])

      subject.all = [
        CARMA::Models::Attachment.new
      ]

      expect(subject.all.size).to eq(1)
      expect(subject.all.first).to be_instance_of(CARMA::Models::Attachment)
    end
  end

  describe '#add' do
    it 'adds an Attachment to @all' do
      expect(subject.all).to eq([])

      subject.add('10-10CG', 'tmp/pdfs/10-10CG_12345.pdf')

      expect(subject.all.size).to eq(1)
      expect(subject.all.first).to be_instance_of(CARMA::Models::Attachment)
      expect(subject.all.first.document_type).to eq('10-10CG')
      expect(subject.all.first.file_path).to eq('tmp/pdfs/10-10CG_12345.pdf')

      subject.add('POA', 'tmp/pdfs/POA_12345.pdf')

      expect(subject.all.size).to eq(2)
      expect(subject.all.second).to be_instance_of(CARMA::Models::Attachment)
      expect(subject.all.second.document_type).to eq('POA')
      expect(subject.all.second.file_path).to eq('tmp/pdfs/POA_12345.pdf')
    end
  end

  describe '#to_request_payload' do
    it 'raises error when :all is empty' do
      expect { subject.to_request_payload }.to raise_error 'must have at least one attachment'
    end

    it 'returns :all attachments in an object with key "records"' do
      %w[10-10CG POA].each_with_index do |document_type, index|
        subject.add('10-10CG', "tmp/pdfs/#{document_type}_12345.pdf")
        expect(subject.all[index]).to receive(:to_request_payload).and_return(:"attachment_data_#{index}")
      end

      expect(subject.to_request_payload).to eq(
        {
          'records' => %i[attachment_data_0 attachment_data_1]
        }
      )
    end
  end
end
