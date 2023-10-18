# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::States::Retriever do
  subject(:retriever) { described_class.new }

  let(:expected_return) do
    {
      id: nil,
      name: 'Alabama',
      code: 'AL'
    }
  end
  let(:entity) { retriever.call.first }

  describe '#call' do
    context 'when successful' do
      it 'returns an array of Entity objects with correct data' do
        parse = JSON.parse(entity.to_json, symbolize_names: true)

        expect(entity).to be_a(AskVAApi::States::Entity)
        expect(parse).to eq(expected_return)
      end
    end
  end
end
