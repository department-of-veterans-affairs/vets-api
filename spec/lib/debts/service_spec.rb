# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Debts::Service do
  describe '#get_letters' do
    it 'should fetch the veterans debt letters data' do
      VCR.use_cassette(
          'debts/get_letters',
          VCR::MATCH_EVERYTHING
        ) do
        described_class.new.get_letters(fileNumber: '000000009')
      end
    end
  end
end
