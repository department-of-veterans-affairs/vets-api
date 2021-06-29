# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::ContestableIssuesController do
  describe '#get_contestable_issues_from_caseflow' do
    before do
      expected_headers = { 'X-VA-SSN' => '872958715', 'X-VA-Receipt-Date' => '2019-12-01' }
      allow_any_instance_of(described_class).to receive(:request_headers).and_return(expected_headers)
      allow_any_instance_of(described_class).to receive(:benefit_type).and_return('')
    end

    it 'filters out any ratingIssueSubjectText that is nil' do
      VCR.use_cassette('caseflow/notice_of_disagreements/contestable_issues') do
        filtered = described_class.new.send(:get_contestable_issues_from_caseflow).body

        expect(filtered['data'].count).to eq(1)
      end
    end

    it 'does not filter if filter: false is passed' do
      VCR.use_cassette('caseflow/notice_of_disagreements/contestable_issues') do
        unfiltered = described_class.new.send(:get_contestable_issues_from_caseflow, filter: false).body

        expect(unfiltered['data'].count).to eq(10)
      end
    end
  end
end
