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

    # rubocop:disable Metrics/ParameterLists
    def build(date_from, date_to, pact_act_data, disability_compensation_count,
              poa_count, itf_count, ews_count)

      @date_from = date_from.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @date_to = date_to.in_time_zone('Eastern Time (US & Canada)').strftime('%a %D %I:%M %p')
      @data = { month: {} }

      pact_act_submissions(pact_act_data)
      disability_compensation_submissions(disability_compensation_count)
      poa_submissions(poa_count)
      itf_submissions(itf_count)
      ews_submissions(ews_count)

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
    # rubocop:enable Metrics/ParameterLists

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

    def pact_act_submissions(pact_act_data)
      pact_act_data = ClaimsApi::ClaimSubmission.where(created_at: @from..@to) if pact_act_data.nil?

      add_monthly_pact_data(pact_act_data)
    end

    def disability_compensation_submissions(disability_compensation_count)
      if disability_compensation_count.nil?
        disability_compensation_count = ClaimsApi::AutoEstablishedClaim
                                        .where(created_at: @from..@to)
                                        .pluck(:id)
                                        .uniq
                                        .size
      end

      add_monthly_data(disability_compensation_count, 'Disability Compensation', 'Form 526')
    end

    def poa_submissions(poa_count)
      if poa_count.nil?
        poa_count = ClaimsApi::PowerOfAttorney
                    .where(created_at: @from..@to)
                    .pluck(:id)
                    .uniq
                    .size
      end

      add_monthly_data(poa_count, 'Power of Attorney', 'Form 2122/2122a')
    end

    def itf_submissions(itf_count)
      if itf_count.nil?
        itf_count = ClaimsApi::IntentToFile.where(created_at: @from..@to)
                                           .pluck(:id)
                                           .uniq
                                           .size
      end

      add_monthly_data(itf_count, 'Intent to File', 'Form 0966')
    end

    def ews_submissions(ews_count)
      if ews_count.nil?
        ews_count = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to)
                                                       .pluck(:id)
                                                       .uniq
                                                       .size
      end

      add_monthly_data(ews_count, 'Evidence Waiver', 'Form 5133')
    end

    def add_monthly_data(records_count, kind, label)
      @data[:month][kind] ||= {}

      @data[:month][kind][label] = records_count
    end

    def add_monthly_pact_data(pact_act_data)
      pact_act_data.pluck(:claim_type).uniq.sort.each do |kind|
        @data[:month][kind] = {}
        subs = pact_act_data.select { |sub| sub[:claim_type] == kind }
        subs.pluck(:consumer_label).uniq.sort.each do |label|
          @data[:month][kind][label] = subs.select { |sub| sub[:consumer_label] == label }.size
        end
      end
    end
  end
end
