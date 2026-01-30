# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AvsBinarySerializer do
  let(:avs_binary) do
    {
      doc_id: '123',
      binary: 'binaryString'
    }
  end
  let(:avs_error) do
    {
      doc_id: '123',
      error: 'errorString'
    }
  end

  describe 'json serialization' do
    context 'with an avs binary' do
      it 'serializes correctly' do
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize([avs_binary], 'avs_binary')
        expect(serialized.to_json).to eq(
          '[{"doc_id":"123","binary":"binaryString"}]'
        )
      end
    end

    context 'with an avs error' do
      it 'serializes correctly' do
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize([avs_error], 'avs_binary')
        expect(serialized.to_json).to eq(
          '[{"doc_id":"123","error":"errorString"}]'
        )
      end
    end

    context 'with an avs binary and error' do
      it 'serializes correctly' do
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize([avs_binary, avs_error], 'avs_binary')
        expect(serialized.to_json).to eq(
          '[{"doc_id":"123","binary":"binaryString"},{"doc_id":"123","error":"errorString"}]'
        )
      end
    end
  end
end
