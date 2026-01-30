# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AvsBinarySerializer do
  let(:avs_binary) do
    {
      document_id: '123',
      binary: 'binaryString'
    }
  end

  let(:avs_error) do
    {
      document_id: '123',
      error: 'errorString'
    }
  end

  describe 'json serialization' do
    context 'with an avs binary' do
      it 'serializes correctly' do
        serialized_hash = described_class.new([avs_binary]).serializable_hash
        expect(serialized_hash).to include(
          data: [{
            id: '123',
            type: :avs_binary,
            attributes: {
              document_id: '123',
              binary: 'binaryString'
            }
          }]
        )
      end
    end

    context 'with an avs error' do
      it 'serializes correctly' do
        serialized_hash = described_class.new([avs_error]).serializable_hash
        expect(serialized_hash).to include(
          data: [{
            id: '123',
            type: :avs_binary,
            attributes: {
              document_id: '123',
              error: 'errorString'
            }
          }]
        )
      end
    end

    context 'with an avs binary and error' do
      it 'serializes correctly' do
        serialized_hash = described_class.new([avs_binary, avs_error]).serializable_hash
        expect(serialized_hash).to include(
          data: [
            {
              id: '123',
              type: :avs_binary,
              attributes: {
                document_id: '123',
                binary: 'binaryString'
              }
            },
            {
              id: '123',
              type: :avs_binary,
              attributes: {
                document_id: '123',
                error: 'errorString'
              }
            }
          ]
        )
      end
    end
  end
end
