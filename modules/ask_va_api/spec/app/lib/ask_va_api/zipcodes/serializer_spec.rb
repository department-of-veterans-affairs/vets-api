# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Zipcodes::Serializer do
  let(:info) do
    {
      zip: '36000',
      city: 'Autaugaville',
      state: 'AL',
      lat: 32.4312,
      lng: -86.6549
    }
  end
  let(:zipcode) { AskVAApi::Zipcodes::Entity.new(info) }
  let(:response) { described_class.new(zipcode) }
  let(:expected_response) do
    { data: { id: nil,
              type: :zipcodes,
              attributes: {
                zipcode: info[:zip],
                city: info[:city],
                state: info[:state],
                lat: info[:lat],
                lng: info[:lng]
              } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
