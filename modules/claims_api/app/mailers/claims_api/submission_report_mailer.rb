# frozen_string_literal: true

module ClaimsApi
  class SubmissionReportMailer < ApplicationMailer
    RECIPIENTS = %w[
      alex.wilson@oddball.io
      austin.covrig@oddball.io
      emily.goodrich@oddball.io
      jennica.stiehl@oddball.io
      kayla.watanabe@adhocteam.us
      matthew.christianson@adhocteam.us
      rockwell.rice@oddball.io
    ].freeze

    def build(date_from, date_to, submissions = nil, yearly_submissions = nil) # rubocop:disable Metrics/MethodLength
      @date_from = date_from.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @date_to = date_to.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @data = { month: {}, year: {} }
      submissions = ClaimsApi::ClaimSubmission.where(created_at: @from..@to) if submissions.nil?

      submissions.pluck(:claim_type).uniq.sort.each do |kind|
        @data[:month][kind] = {}
        subs = submissions.select { |sub| sub[:claim_type] == kind }
        subs.pluck(:consumer_label).uniq.sort.each do |label|
          @data[:month][kind][label] = subs.select { |sub| sub[:consumer_label] == label }.size
        end
      end

      if yearly_submissions.nil?
        year_start = Date.new(Time.zone.today.year, 1, 1)
        year_end = Date.new(Time.zone.today.year + 1, 1, 1)
        yearly_submissions = ClaimsApi::ClaimSubmission.where('created_at > ? AND created_at < ?', year_start, year_end)
      end

      yearly_submissions.pluck(:claim_type).uniq.sort.each do |kind|
        @data[:year][kind] = {}
        subs = yearly_submissions.select { |sub| sub[:claim_type] == kind }
        subs.pluck(:consumer_label).uniq.sort.each do |label|
          @data[:year][kind][label] = subs.select { |sub| sub[:consumer_label] == label }.size
        end
      end
      @data.deep_symbolize_keys!

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: RECIPIENTS,
        subject: 'Benefits Claims Monthly Submission Report', # rubocop:disable Rails/I18nLocaleTexts
        content_type: 'text/html',
        body:
      )
    end

    private

    def path
      ClaimsApi::Engine.root.join(
        'app',
        'views',
        'claims_api',
        'submission_report_mailer',
        'submission_report.html.erb'
      )
    end
  end
end
