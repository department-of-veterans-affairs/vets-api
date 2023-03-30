# frozen_string_literal: true

require 'appeals_api/decision_review_report'

module AppealsApi
  class DecisionReviewMailer < ApplicationMailer
    def build(date_from:, date_to:, recipients:, friendly_duration: '')
      @report = DecisionReviewReport.new(from: date_from, to: date_to)
      @friendly_duration = friendly_duration
      @friendly_env = (Settings.vsp_environment || Rails.env).titleize

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: recipients,
        subject: "#{@friendly_duration} Decision Review API report (#{@friendly_env})",
        content_type: 'text/html',
        body:
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
