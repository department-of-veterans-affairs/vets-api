# frozen_string_literal: true

class AppealsApiDecisionReviewPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/appeals_api_decision_review
  def build
    to = Time.zone.now
    from = Time.at(0).utc

    AppealsApi::DecisionReviewMailer.build(date_from: from, date_to: to, recipients: ['hello@example.com'])
  end
end
