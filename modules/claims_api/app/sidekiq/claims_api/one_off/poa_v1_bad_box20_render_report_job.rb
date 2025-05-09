# frozen_string_literal: true

module ClaimsApi
  module OneOff
    class PoaV1BadBox20RenderReportJob < ClaimsApi::ServiceBase
      sidekiq_options retry: 5 # Retry for ~10 mins
      LOG_TAG = 'claims_api_poa_box20_report_job'

      # rubocop:disable Metrics/MethodLength
      def perform(consumer_id, emails = [])
        if consumer_id.blank?
          ClaimsApi::Logger.log LOG_TAG, level: :warn, detail: 'Invlaid CID.'
          slack_alert_on_failure LOG_TAG, 'Invalid CID'
          return
        end
        if emails.blank? || !emails.all? { |e| e.downcase =~ /@va\.gov$/ }
          ClaimsApi::Logger.log LOG_TAG, level: :warn, detail: 'Invalid email address list. All emails must be @va.gov'
          slack_alert_on_failure LOG_TAG, 'Invalid email address list.'
          return
        end
        ClaimsApi::Logger.log(LOG_TAG, detail: 'Started processing')
        date_range = Date.parse('2025-01-07').beginning_of_day...Date.parse('2025-04-03').end_of_day
        poas = ClaimsApi::PowerOfAttorney.where cid: consumer_id, created_at: date_range

        memo = +'poa_id,eauth_pnid,created_date'
        num_records = 0

        poas.find_each(batch_size: 75) do |poa|
          next if poa.form_data['consentLimits'].present?

          memo << "\n<br>"
          memo << [poa.id, poa.auth_headers['va_eauth_pnid'], poa.created_at.iso8601].join(',')
          num_records += 1
        end

        if num_records.zero?
          ClaimsApi::Logger.log LOG_TAG, level: :warn, detail: 'No records found.'
          slack_alert_on_failure LOG_TAG, 'No records found.'
          return
        end

        ClaimsApi::Logger.log LOG_TAG, detail: "Found #{num_records} record(s)"
        ClaimsApi::Logger.log LOG_TAG, detail: 'Sending email'
        # rubocop:disable Rails/I18nLocaleTexts
        ApplicationMailer.new.mail(to: emails, subject: 'POA v1 Bad Box20 PDF Render Report', content_type: 'text/html',
                                   body: memo).deliver
        # rubocop:enable Rails/I18nLocaleTexts
        ClaimsApi::Logger.log LOG_TAG, detail: 'Email sent. Job complete.'
      rescue => e
        # Only alert on the class name since an email exception may output the body, which would have PII
        ClaimsApi::Logger.log LOG_TAG, detail: 'Exception thrown.', level: :error, error: e.class.name
        slack_alert_on_failure LOG_TAG, "Exception thrown: #{e.class}"
        raise e
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
