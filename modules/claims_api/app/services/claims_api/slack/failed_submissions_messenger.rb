# frozen_string_literal: true

require 'common/client/base'

module ClaimsApi
  module Slack
    class FailedSubmissionsMessenger
      # rubocop:disable Metrics/ParameterLists
      def initialize(claims, poa, itf, ews, from, to, env)
        @errored_claims = claims
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
        errored_submission_message << "*#{submission_type} Errors* \nTotal: #{errored_submissions.count} \n```"
        errored_submissions.each do |submission_id|
          errored_submission_message << "#{submission_id} \n"
        end
        errored_submission_message << "```  \n\n"
        errored_submission_message
      end
    end
  end
end
