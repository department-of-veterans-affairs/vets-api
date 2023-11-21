# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::SubTopics::Serializer do
  let(:info) do
    {
      topicId: 1,
      id: 1,
      subtopic: 'Claim Access Issue'
    }
  end
  let(:subtopic) { AskVAApi::SubTopics::Entity.new(info) }
  let(:response) { described_class.new(subtopic) }
  let(:expected_response) do
    { data: { id: '1',
              type: :subtopics,
              attributes: { name: 'Claim Access Issue' } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
