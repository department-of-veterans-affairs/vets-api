# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

# rubocop:disable RSpec/FilePath
RSpec.describe VirtualRegionalOffice::Client, :vcr do
  describe '#assess_claim' do
    context 'with a sleep apnea request' do
      subject(:client) do
        described_class.new({
                              veteran_icn: '9000682',
                              diagnostic_code: '7101',
                              claim_submission_id: '1234'
                            }).assess_claim
      end

      it 'returns an assessment' do
        VCR.use_cassette('virtual_regional_office/health_assessment') do
          expect(subject.body['veteranIcn']).to eq('9000682')
        end
      end
    end
  end
end
# rubocop:enable RSpec/FilePath
