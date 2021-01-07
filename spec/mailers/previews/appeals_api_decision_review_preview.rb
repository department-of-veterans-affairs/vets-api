# frozen_string_literal: true

class AppealsApiDecisionReviewPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/appeals_api/decision_review/report
  def build
    from = 1.week.ago.utc
    to = Time.zone.now

    AppealsApi::DecisionReviewMailer.build(from: from, to: to)
  end
end
