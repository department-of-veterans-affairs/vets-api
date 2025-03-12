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

  describe '#to_hash' do
    it 'returns :all attachments as hash' do
      subject.add('10-10CG', 'tmp/pdfs/10-10CG_12345.pdf')
      subject.add('POA', 'tmp/pdfs/POA_12345.pdf')

      expect(subject.all[0]).to receive(:to_hash).and_return(:hash_1)
      expect(subject.all[1]).to receive(:to_hash).and_return(:hash_2)

      result = subject.to_hash
      expect(result[:data]).to eq(%i[hash_1 hash_2])
      expect(result[:has_errors]).to be_nil
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

  describe '#submit!' do
    it 'returns CARMA\'s response and sets :response and :all attachment\'s ids', run_at: '2020-02-27T15:12:05Z' do
      [
        ['10-10CG', 'tmp/pdfs/10-10CG_12345.pdf'],
        ['POA', 'tmp/pdfs/POA_12345.pdf']
      ].each_with_index do |data, index|
        document_type = data[0]
        file_path     = data[1]

        subject.add(document_type, file_path)

        expect(subject.all[index]).to receive(:to_request_payload).and_return(
          :"attachment_payload_#{index}"
        )
      end

      expected_request_payload = {
        'records' => %i[attachment_payload_0 attachment_payload_1]
      }

      expected_response = {
        'hasErrors' => false,
        'results' => [
          {
            'referenceId' => '1010CG',
            'id' => '06835000000YpsjAAC'
          },
          {
            'referenceId' => 'POA',
            'id' => '09944000000YabjARD'
          }
        ]
      }

      carma_client = double
      expect(carma_client).to receive(:upload_attachments).with(
        expected_request_payload
      ).and_return(
        expected_response
      )

      subject.submit!(carma_client)

      expect(subject.response).to eq(expected_response)
      expect(subject.has_errors).to be(false)
      expect(subject.all[0].id).to eq(expected_response['results'][0]['id'])
      expect(subject.all[1].id).to eq(expected_response['results'][1]['id'])
    end

    context 'when re-submitted' do
      it 'returns previous @response' do
        [
          ['10-10CG', 'tmp/pdfs/10-10CG_12345.pdf'],
          ['POA', 'tmp/pdfs/POA_12345.pdf']
        ].each_with_index do |data, index|
          document_type = data[0]
          file_path     = data[1]

          subject.add(document_type, file_path)

          expect(subject.all[index]).to receive(:to_request_payload).and_return(
            :"attachment_payload_#{index}"
          )
        end

        expected_request_payload = {
          'records' => %i[attachment_payload_0 attachment_payload_1]
        }

        expected_response = {
          'hasErrors' => false,
          'results' => [
            {
              'referenceId' => '1010CG',
              'id' => '06835000000YpsjAAC'
            },
            {
              'referenceId' => 'POA',
              'id' => '09944000000YabjARD'
            }
          ]
        }

        carma_client = double
        expect(carma_client).to receive(:upload_attachments).with(
          expected_request_payload
        ).and_return(
          expected_response
        )

        5.times { subject.submit!(carma_client) }

        expect(subject.response).to eq(expected_response)
        expect(subject.has_errors).to be(false)
        expect(subject.all[0].id).to eq(expected_response['results'][0]['id'])
        expect(subject.all[1].id).to eq(expected_response['results'][1]['id'])
      end
    end
  end
end
