# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

RSpec.describe VirtualRegionalOffice::Client, :vcr do
  let(:client) { described_class.new }

  before do
    allow(StatsD).to receive(:increment)
  end

  describe '#get_max_rating_for_diagnostic_codes' do
    context 'whe the request is successful' do
      subject { client.get_max_rating_for_diagnostic_codes(diagnostic_codes: [6260]) }

      it 'returns max ratings and logs monitor metrics' do
        VCR.use_cassette('virtual_regional_office/max_ratings') do
          expect(subject.body['ratings'].first['diagnostic_code']).to eq(6260)
          expect(subject.body['ratings'].first['max_rating']).to eq(10)
          expect(StatsD).not_to have_received(:increment).with('api.vro.get_max_rating_for_diagnostic_codes.fail',
                                                               anything)
          expect(StatsD).to have_received(:increment).with('api.vro.get_max_rating_for_diagnostic_codes.total')
        end
      end
    end

    context 'whe the request is unsuccessful' do
      subject { client.get_max_rating_for_diagnostic_codes(diagnostic_codes: [6260]) }

      it 'fails to return max ratings and logs monitor metrics' do
        VCR.use_cassette('virtual_regional_office/max_ratings_failure') do
          expect { subject }.to raise_error(Common::Client::Errors::ClientError)

          expected_failure_tags = ['error:CommonClientErrorsClientError', 'status:500']
          expect(StatsD).to have_received(:increment).with('api.vro.get_max_rating_for_diagnostic_codes.fail',
                                                           { tags: expected_failure_tags })
          expect(StatsD).to have_received(:increment).with('api.vro.get_max_rating_for_diagnostic_codes.total')
        end
      end
    end
  end
end
