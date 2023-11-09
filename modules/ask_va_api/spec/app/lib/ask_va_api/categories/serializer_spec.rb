# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Categories::Serializer do
  let(:info) do
    {
      id: 1,
      category: 'Appeals of Denied Claims'
    }
  end
  let(:category) { AskVAApi::Categories::Entity.new(info) }
  let(:response) { described_class.new(category) }
  let(:expected_response) do
    { data: { id: '1',
              type: :categories,
              attributes: { name: 'Appeals of Denied Claims' } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
