# frozen_string_literal: true

require 'appeals_api/decision_review_report'

module AppealsApi
  class DecisionReviewMailer < ApplicationMailer
    def build(date_from:, date_to:)
      @report = DecisionReviewReport.new(from: date_from, to: date_to)

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: Settings.modules_appeals_api.report_recipients,
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
