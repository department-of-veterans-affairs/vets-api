# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Provinces::Serializer do
  let(:info) { { name: 'Alberta', abbreviation: 'AB' } }
  let(:province) { AskVAApi::Provinces::Entity.new(info) }
  let(:response) { described_class.new(province) }
  let(:expected_response) do
    { data: { id: nil,
              type: :provinces,
              attributes: { name: info[:name], abv: info[:abbreviation] } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
