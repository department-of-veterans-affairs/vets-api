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
          expect(subject.body['responseBody']['classification_name']).to eq('asthma')
        end
      end
    end
  end
end
# rubocop:enable RSpec/FilePath
