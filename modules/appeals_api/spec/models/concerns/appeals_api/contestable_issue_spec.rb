# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::ContestableIssue do
  let(:raw_issue_data) do
    {
      'type' => 'contestableIssue',
      'attributes' => {
        'issue' => 'tinnitus',
        'decisionDate' => '1900-01-01',
        'decisionIssueId' => 1,
        'ratingIssueReferenceId' => '2',
        'ratingDecisionReferenceId' => '3',
        'socDate' => '1999-01-05'
      }
    }
  end

  describe '#decision_date' do
    it 'returns nil if decisionDate is null' do
      issue = AppealsApi::ContestableIssue.new(
        raw_issue_data.merge('attributes' => { 'decisionDate' => nil })
      )

      expect(issue.decision_date).to be_nil
    end

    it 'parses and returns decision_date' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.decision_date.inspect).to eq('Mon, 01 Jan 1900')
    end
  end

  describe '#decision_date_string' do
    it 'returns the raw input value' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.decision_date_string).to eq('1900-01-01')
    end
  end

  describe '#soc_date' do
    it 'returns nil if socDate is null' do
      issue = AppealsApi::ContestableIssue.new(
        raw_issue_data.merge('attributes' => { 'socDate' => nil })
      )

      expect(issue.soc_date).to be_nil
    end

    it 'parses and returns soc_date' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.soc_date.inspect).to eq('Tue, 05 Jan 1999')
    end
  end

  describe '#soc_date_string' do
    it 'returns the raw input value' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.soc_date_string).to eq('1999-01-05')
    end
  end

  describe '#text' do
    it 'returns the issue text' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.text).to eq('tinnitus')
    end
  end

  describe '#text_exists?' do
    it 'returns true if issue is not nil' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.text_exists?).to be(true)
    end

    it 'returns false if issue is nil' do
      issue = AppealsApi::ContestableIssue.new(
        raw_issue_data.merge('attributes' => { 'issue' => nil })
      )

      expect(issue.text_exists?).to be(false)
    end
  end

  describe '#soc_date_past?' do
    it 'returns true if soc date is in the past' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.soc_date_past?).to be(true)
    end

    it 'returns false if soc date isn\'t in the past' do
      # this test will fail in 100 years.

      issue = AppealsApi::ContestableIssue.new(
        raw_issue_data.merge('attributes' => { 'socDate' => '3021-06-18' })
      )

      expect(issue.soc_date_past?).to be(false)
    end
  end

  describe '#decision_date_past?' do
    it 'returns true if decision date is in the past' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.decision_date_past?).to be(true)
    end

    it 'returns false if decision date isn\'t in the past' do
      # this test will fail in 100 years.

      issue = AppealsApi::ContestableIssue.new(
        raw_issue_data.merge('attributes' => { 'decisionDate' => '3021-06-18' })
      )

      expect(issue.decision_date_past?).to be(false)
    end
  end

  describe '#soc_date_formatted' do
    it 'formats the soc date' do
      issue = AppealsApi::ContestableIssue.new(raw_issue_data)

      expect(issue.soc_date_formatted).to eq('01-05-1999')
    end
  end
end
