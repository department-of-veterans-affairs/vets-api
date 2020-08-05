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
          expect(StatsD).to receive(:increment).once.with(
            'api.debts.get_letters.fail', tags: [
              'error:Common::Client::Errors::ClientError', 'status:400'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.debts.get_letters.total'
          )
          expect { described_class.new.get_letters(fileNumber: '') }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) do |e|
            expect(e.message).to match(/DEBTS400/)
          end
        end
      end
    end
  end
end
