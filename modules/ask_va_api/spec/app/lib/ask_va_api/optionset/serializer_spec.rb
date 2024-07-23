# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Optionset::Serializer do
  let(:info) do
    {
      Id: 722_310_000,
      Name: 'Air Force'
    }
  end
  let(:optionset) { AskVAApi::Optionset::Entity.new(info) }
  let(:response) { described_class.new(optionset) }
  let(:expected_response) { { data: { id: '722310000', type: :optionsets, attributes: { name: 'Air Force' } } } }

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
