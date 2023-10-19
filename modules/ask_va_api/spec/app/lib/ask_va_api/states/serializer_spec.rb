# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::States::Serializer do
  let(:info) { { stateName: 'Colorado', code: 'CO' } }
  let(:state) { AskVAApi::States::Entity.new(info) }
  let(:response) { described_class.new(state) }
  let(:expected_response) do
    { data: { id: nil,
              type: :states,
              attributes: { name: info[:stateName], code: info[:code] } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
