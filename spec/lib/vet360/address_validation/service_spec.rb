# frozen_string_literal: true

require 'rails_helper'

describe Vet360::AddressValidation::Service do
  describe '#city_state_province' do
    it 'should return city state for a given zip code' do
      described_class.new(nil).city_state_province('85001')
    end
  end
end
