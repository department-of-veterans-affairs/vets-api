# frozen_string_literal: true

class AppealsApi::ContestableIssue
  def initialize(issue)
    @issue = issue
  end

  def decision_date
    return unless decision_date_string

    parse_date(decision_date_string)
  end

  def decision_date_string
    issue.dig('attributes', 'decisionDate')
  end

  def decision_date_past?
    in_the_past?(decision_date)
  end

  def soc_date
    return unless soc_date_string

    parse_date(soc_date_string)
  end

  def soc_date_string
    issue.dig('attributes', 'socDate')
  end

  def soc_date_formatted
    soc_date&.strftime('%m-%d-%Y')
  end

  def soc_date_past?
    in_the_past?(soc_date)
  end

  def text
    issue.dig('attributes', 'issue')
  end

  def text_exists?
    text.present?
  end

  delegate :[], to: :issue

  private

  attr_reader :issue

  def in_the_past?(date)
    date < Time.zone.today
  end

  def parse_date(date)
    date.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(date)
  rescue ArgumentError
    nil
  end
end
