# frozen_string_literal: true

class AppealsApi::HigherLevelReview::ContestableIssue
  def initialize(issue)
    @issue = issue
  end

  def decision_date
    return unless decision_date_string

    AppealsApi::HigherLevelReview::Date.new(decision_date_string)
  end

  def decision_date_string
    issue.dig('attributes', 'decisionDate').to_s
  end

  def soc_date
    return unless soc_date_string

    AppealsApi::HigherLevelReview::Date.new(soc_date_string)
  end

  def soc_date_string
    issue.dig('attributes', 'socDate')
  end

  def text
    issue.dig('attributes', 'issue')
  end

  delegate :[], to: :issue

  def text_exists?
    text.present?
  end

  private

  attr_reader :issue
end
