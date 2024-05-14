# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

RSpec.describe VirtualRegionalOffice::Client, :vcr do
  let(:client) { described_class.new }

  before do
    allow(StatsD).to receive(:increment)
  end

  describe '#classify_single_contention' do
    context 'with a contention classification request' do
      subject do
        client.classify_single_contention(
          diagnostic_code: 5235,
          claim_id: 190,
          form526_submission_id: 179
        )
      end

      it 'returns a classification and logs monitor metric' do
        VCR.use_cassette('virtual_regional_office/contention_classification') do
          expect(subject.body['classification_name']).to eq('asthma')
          expect(StatsD).not_to have_received(:increment).with('api.vro.classify_single_contention.fail', anything)
          expect(StatsD).to have_received(:increment).with('api.vro.classify_single_contention.total')
        end
      end

      it 'fails to returns a classification and logs monitor metric' do
        VCR.use_cassette('virtual_regional_office/contention_classification_failure') do
          expect { subject }.to raise_error(Common::Client::Errors::ClientError)

          expected_failure_tags = ['error:CommonClientErrorsClientError', 'status:500']
          expect(StatsD).to have_received(:increment).with('api.vro.classify_single_contention.fail',
                                                           { tags: expected_failure_tags })
          expect(StatsD).to have_received(:increment).with('api.vro.classify_single_contention.total')
        end
      end
    end
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

  describe '#merge_end_products' do
    subject { client.merge_end_products(pending_claim_id: '12345', ep400_id: '12346') }

    context 'when the request is successful' do
      it 'returns a accepted job and logs monitor metrics' do
        VCR.use_cassette('virtual_regional_office/ep_merge') do
          expect(subject.body['job']).to have_key('job_id')
          expect(StatsD).not_to have_received(:increment).with('api.vro.merge_end_products.fail', anything)
          expect(StatsD).to have_received(:increment).with('api.vro.merge_end_products.total')
        end
      end
    end

    context 'when the request is unsuccessful' do
      it 'raises an exception and log metrics' do
        VCR.use_cassette('virtual_regional_office/ep_merge_failure') do
          expect { subject }.to raise_error(Common::Client::Errors::ClientError)

          expected_failure_tags = ['error:CommonClientErrorsClientError', 'status:500']
          expect(StatsD).to have_received(:increment).with('api.vro.merge_end_products.fail',
                                                           { tags: expected_failure_tags })
          expect(StatsD).to have_received(:increment).with('api.vro.merge_end_products.total')
        end
      end
    end
  end
end
