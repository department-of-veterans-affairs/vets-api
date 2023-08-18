# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

# rubocop:disable RSpec/FilePath
RSpec.describe VirtualRegionalOffice::Client, :vcr do
  describe '#classify_contention_by_diagnostic_code' do
    context 'with a contention classification request' do
      subject(:client) do
        described_class.new.classify_contention_by_diagnostic_code(
          diagnostic_code: 5235,
          claim_id: 190,
          form526_submission_id: 179
        )
      end

      it 'returns a classification' do
        VCR.use_cassette('virtual_regional_office/contention_classification') do
          expect(subject.body['classification_name']).to eq('asthma')
        end
      end
    end
  end

  describe '#get_max_rating_for_diagnostic_codes' do
    context 'with a max ratings request' do
      subject(:client) do
        described_class.new.get_max_rating_for_diagnostic_codes(
          diagnostic_codes: [6260]
        )
      end

      it 'returns a classification' do
        VCR.use_cassette('virtual_regional_office/max_ratings') do
          expect(subject.body['ratings'].first['diagnostic_code']).to eq(6260)
          expect(subject.body['ratings'].first['max_rating']).to eq(10)
        end
      end
    end
  end
end
# rubocop:enable RSpec/FilePath
