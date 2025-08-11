# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/configuration'

RSpec.describe IvcChampva::VesApi::Configuration do
  describe 'timeouts' do
    it 'sets the open_timeout to at least 20 seconds' do
      expect(described_class.open_timeout).to be >= 20
    end

    it 'sets the read_timeout to at least 20 seconds' do
      expect(described_class.read_timeout).to be >= 20
    end
  end
end
