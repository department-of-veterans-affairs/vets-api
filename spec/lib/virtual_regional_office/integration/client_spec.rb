# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

RSpec.describe VirtualRegionalOffice::Client, :vcr do
  let(:client) { described_class.new }

  describe '#classify_single_contention' do
    context 'with a contention classification request' do
      subject do
        client.classify_single_contention(
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
      subject { client.get_max_rating_for_diagnostic_codes(diagnostic_codes: [6260]) }

      it 'returns max ratings' do
        VCR.use_cassette('virtual_regional_office/max_ratings') do
          expect(subject.body['ratings'].first['diagnostic_code']).to eq(6260)
          expect(subject.body['ratings'].first['max_rating']).to eq(10)
        end
      end
    end
  end

  describe '#merge_end_products' do
    subject { client.merge_end_products(pending_claim_id: '12345', ep400_id: '12346') }

    context 'when the request is successful' do
      it 'returns a successful job' do
        VCR.use_cassette('virtual_regional_office/ep_merge') do
          expect(subject.body['job']).to have_key('job_id')
        end
      end
    end

    context 'when the request is unsuccessful' do
      it 'raises an exception' do
        VCR.use_cassette('virtual_regional_office/ep_merge_failure') do
          expect { subject }.to raise_error(Common::Client::Errors::ClientError)
        end
      end
    end
  end
end
