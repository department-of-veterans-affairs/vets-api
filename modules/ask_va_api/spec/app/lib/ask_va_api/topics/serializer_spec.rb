# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Topics::Serializer do
  let(:info) do
    {
      categoryId: 1,
      id: 1,
      topic: 'All other Questions'
    }
  end
  let(:topic) { AskVAApi::Topics::Entity.new(info) }
  let(:response) { described_class.new(topic) }
  let(:expected_response) do
    { data: { id: '1',
              type: :topics,
              attributes: { name: 'All other Questions' } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
