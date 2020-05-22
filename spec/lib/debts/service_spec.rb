# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Debts::Service do
  describe '#get_letters' do
    it 'fetches the veterans debt letters data' do
      VCR.use_cassette(
        'debts/get_letters',
        VCR::MATCH_EVERYTHING
      ) do
        res = described_class.new.get_letters(fileNumber: '000000009')
        expect(JSON.parse(res.to_json)[0]['fileNumber']).to eq('000000009')
      end
    end
  end
end
