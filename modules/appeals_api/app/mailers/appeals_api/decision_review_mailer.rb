# frozen_string_literal: true

require 'appeals_api/decision_review_report'

module AppealsApi
  class DecisionReviewMailer < ApplicationMailer
    RECIPIENTS = %w[
      premal.shah@va.gov
      kelly@adhocteam.us
      laura.trager@adhocteam.us
      drew.fisher@adhocteam.us
      jack.schuss@oddball.io
      nathan.wright@oddball.io
    ].freeze

    def build(date_from:, date_to:)
      @report = DecisionReviewReport.new(from: date_from, to: date_to)

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Decision Review API report',
        content_type: 'text/html',
        body: body
      )
    end

    private

    def path
      AppealsApi::Engine.root.join(
        'app',
        'views',
        'appeals_api',
        'decision_review_mailer',
        'mailer.html.erb'
      )
    end
  end
end
