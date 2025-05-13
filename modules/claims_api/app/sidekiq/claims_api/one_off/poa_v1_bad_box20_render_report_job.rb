# frozen_string_literal: true

module ClaimsApi
  module OneOff
    class PoaV1BadBox20RenderReportMailer < ApplicationMailer
      def build(emails, csv_str)
        # rubocop:disable Rails/I18nLocaleTexts
        mail to: emails, subject: 'POA v1 Bad Box20 PDF Render Report', content_type: 'text/html', body: csv_str
        # rubocop:enable Rails/I18nLocaleTexts
      end
    end

    class PoaV1BadBox20RenderReportJob < ClaimsApi::ServiceBase
      sidekiq_options retry: 5 # Retry for ~10 mins

      attr_accessor :consumer_id, :emails

      LOG_TAG = 'claims_api_poa_box20_report_job'

      # rubocop:disable Metrics/MethodLength
      def perform(consumer_id, emails = [], start_date = nil, finish_date = nil)
        @consumer_id = consumer_id
        @emails = emails
        start_date ||= '2025-01-07'
        finish_date ||= '2025-04-03'

        if consumer_id.blank?
          ClaimsApi::Logger.log LOG_TAG, level: :warn, detail: 'Invalid CID'
          slack_alert_on_failure LOG_TAG, 'Invalid CID'
          return
        end
        if emails.blank? || !emails.all? { |e| e.downcase =~ /@va\.gov$/ }
          ClaimsApi::Logger.log LOG_TAG, level: :warn, detail: 'Invalid email address list. All emails must be @va.gov'
          slack_alert_on_failure LOG_TAG, 'Invalid email address list.'
          return
        end

        ClaimsApi::Logger.log(LOG_TAG, detail: 'Started processing')
        (Date.parse(start_date)..Date.parse(finish_date)).group_by(&:cweek).each_value do |dates|
          process_date_range dates.first.beginning_of_day..dates.last.end_of_day
        end
        ClaimsApi::Logger.log LOG_TAG, detail: 'Job complete'
      rescue => e
        # Only alert on the class name since an email exception may output the body, which would have PII
        ClaimsApi::Logger.log LOG_TAG, detail: 'Exception thrown', level: :error, error: e.class.name
        slack_alert_on_failure LOG_TAG, "Exception thrown: #{e.class}"
        raise e
      end
      # rubocop:enable Metrics/MethodLength

      protected

      def process_date_range(date_range)
        poas = ClaimsApi::PowerOfAttorney.where cid: consumer_id, created_at: date_range

        start_date = date_range.first.to_date.to_s
        finish_date = date_range.last.to_date.to_s

        memo = +"<h3>IDS from #{start_date} to #{finish_date}</h3>"
        memo << 'poa_id,eauth_pnid,created_date'
        num_records = 0

        poas.find_each(batch_size: 100) do |poa|
          next if poa.form_data['consentLimits'].present?

          memo << "\n<br>"
          memo << [poa.id, poa.auth_headers['va_eauth_pnid'], poa.created_at.iso8601].join(',')
          num_records += 1
        end

        if num_records.zero?
          ClaimsApi::Logger.log LOG_TAG, detail: "No records for week of #{start_date}"
          return
        end

        ClaimsApi::Logger.log LOG_TAG, detail: "Found #{num_records} record(s)"
        ClaimsApi::Logger.log LOG_TAG, detail: "Sending email for week of #{start_date}"
        ClaimsApi::OneOff::PoaV1BadBox20RenderReportMailer.build(emails, memo).deliver_now
        ClaimsApi::Logger.log LOG_TAG, detail: 'Email sent'
      end
    end
  end
end
