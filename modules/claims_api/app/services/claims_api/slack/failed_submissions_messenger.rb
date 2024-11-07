# frozen_string_literal: true

require 'common/client/base'

module ClaimsApi
  module Slack
    class FailedSubmissionsMessenger
      # rubocop:disable Metrics/ParameterLists
      def initialize(claims, va_claims, poa, itf, ews, from, to, env)
        @errored_claims = claims
        @va_gov_errored_claims = va_claims
        @errored_poa = poa
        @errored_itf = itf
        @errored_ews = ews
        @to = to
        @from = from
        @environment = env
      end
      # rubocop:enable Metrics/ParameterLists

      def notify!
        slack_client = SlackNotify::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                               channel: '#api-benefits-claims-alerts',
                                               username: 'Failed Submissions Messenger')

        notification_message = build_notification_message
        slack_client.notify(notification_message)
      end

      private

      def build_notification_message
        message = ''.dup
        message << message_heading
        message << build_submission_information(@errored_claims, 'Disability Compensation')
        message << build_submission_information(@va_gov_errored_claims, 'Va Gov Disability Compensation')
        message << build_submission_information(@errored_poa, 'Power of Attorney')
        message << build_submission_information(@errored_itf, 'Intent to File')
        message << build_submission_information(@errored_ews, 'Evidence Waiver')
        message
      end

      def message_heading
        heading = ''.dup
        heading << build_heading_message
        heading
      end

      def build_heading_message
        heading_message = ''.dup
        heading_text = "*ERRORED SUBMISSIONS* \n\n#{@from} - #{@to} \nThe following submissions have encountered " \
                       "errors in *#{@environment}*. \n\n"
        heading_message << heading_text
        heading_message
      end

      def build_submission_information(errored_submissions, submission_type)
        return '' if errored_submissions.count.zero?

        errored_submission_message = ''.dup
        if submission_type == 'Intent to File'
          errored_submission_message << "*#{submission_type} Errors* \nTotal: #{errored_submissions.count} \n\n"
        elsif submission_type == 'Va Gov Disability Compensation'
          errored_submission_message << "*#{submission_type} Errors* \nTotal: #{errored_submissions.count} \n\n```"
          errored_submissions.each do |submission_id|
            errored_submission_message << "#{link_value(submission_id)}#{submission_id}> \n"
          end
          errored_submission_message << "```  \n\n"
        else
          errored_submission_message << "*#{submission_type} Errors* \nTotal: #{errored_submissions.count} \n\n```"
          errored_submissions.each do |submission_id|
            errored_submission_message << "#{submission_id} \n"
          end
          errored_submission_message << "```  \n\n"
        end
        errored_submission_message
      end

      def link_value(id)
        time_stamps = datadog_timestamps

        "<https://vagov.ddog-gov.com/logs?query='#{id}'&agg_m=count&agg_m_source=base&agg_t=count&cols=" \
          'host%2Cservice&fromUser=true&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=' \
          "desc&viz=stream&from_ts=#{time_stamps[0]}&to_ts=#{time_stamps[1]}&live=true|"
      end

      # set the range to go back 3 days.  Link is based on an ID so any additional range should
      # not add additional noise, but this covers the weekend for Monday morning links
      def datadog_timestamps
        current = Time.now.to_i * 1000 # Data dog uses milliseconds
        three_days_ago = current - 259_200_000 # Three days ago

        [three_days_ago, current]
      end
    end
  end
end
