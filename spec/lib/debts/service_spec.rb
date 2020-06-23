# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Debts::Service do
  describe '#get_letters' do
    context 'with a valid ssn' do
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

    context 'without a valid ssn' do
      it 'returns a bad request error' do
        VCR.use_cassette(
          'debts/get_letters_empty_ssn',
          VCR::MATCH_EVERYTHING
        ) do
          res = described_class.new.get_letters(fileNumber: '')
          expect(JSON.parse(res.to_json)['message']).to eq('Bad request')
        end
      end
    end
  end
end
