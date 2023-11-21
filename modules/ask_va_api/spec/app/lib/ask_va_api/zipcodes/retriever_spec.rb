# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Zipcodes::Retriever do
  subject(:retriever) { described_class.new(zip:) }

  let(:expected_return) do
    {
      id: nil,
      zipcode: '36010',
      city: 'Autaugaville',
      state: 'AL',
      lat: 32.4312,
      lng: -86.6549
    }
  end
  let(:entity) { retriever.call.first }

  describe '#call' do
    context 'when successful' do
      let(:zip) { '3601' }

      it 'returns an array of Entity objects with correct data' do
        parse = JSON.parse(entity.to_json, symbolize_names: true)

        expect(entity).to be_a(AskVAApi::Zipcodes::Entity)
        expect(parse).to eq(expected_return)
        expect(retriever.call.size).to eq(10)
      end
    end

    context 'when not successful' do
      let(:zip) { '4000' }

      it 'returns an empty array' do
        expect(retriever.call).to be_empty
      end
    end
  end
end
