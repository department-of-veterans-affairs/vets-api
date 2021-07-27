# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::HigherLevelReviews::ContestableIssuesController do
  describe '#get_contestable_issues_from_caseflow' do
    subject { described_class.new.send(:get_contestable_issues_from_caseflow).body }

    before do
      expected_headers = { 'X-VA-SSN' => '872958715', 'X-VA-Receipt-Date' => '2019-12-01' }
      allow_any_instance_of(described_class).to receive(:request_headers).and_return(expected_headers)
      allow_any_instance_of(described_class).to receive(:benefit_type).and_return('compensation')
    end

    it 'retrieves contestable_issues from Caseflow successfully' do
      VCR.use_cassette('caseflow/higher_level_reviews/contestable_issues') do
        expect(subject).to be_a Hash
        expect(subject['data']).to be_an Array
        expect(subject['data'].first).to be_a Hash
        expect(subject['data'].first['type']).to eq 'contestableIssue'
      end
    end

    context 'Caseflow returns a 4xx response' do
      before do
        allow_any_instance_of(Caseflow::Service).to receive(:get_contestable_issues) do
          raise Common::Exceptions::BackendServiceException.new(nil, {}, 400, { 'errors' => [] })
        end
      end

      it 'returns Caseflow\'s error' do
        expect(subject).to be_a Hash
        expect(subject['errors']).to be_an Array
      end
    end

    context 'Caseflow returns a 5xx response' do
      before do
        allow_any_instance_of(Caseflow::Service).to receive(:get_contestable_issues) do
          raise Common::Exceptions::BackendServiceException.new(nil, {}, 500, { 'data' => 'Hello!' })
        end
      end

      it 'raises an exception' do
        expect { subject }.to raise_error Common::Exceptions::BackendServiceException
      end
    end
  end
end
