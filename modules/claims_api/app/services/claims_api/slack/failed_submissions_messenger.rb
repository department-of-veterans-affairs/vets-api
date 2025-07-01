# frozen_string_literal: true

require 'common/client/base'

module ClaimsApi
  module Slack
    class FailedSubmissionsMessenger
      # Transaction IDs, despite the name, can have some pretty wild stuff in them. Whitelist values we find useful.
      # Assumes comparison string is upcase'd for matching
      TID_SUBSTRING_WHITELIST = %w[
        FORM526SUBMISSION
      ].freeze

      def initialize(options = {})
        @unresolved_errored_claims = options[:unresolved_errored_claims]
        @errored_poa = options[:errored_poa] # Array of id
        @errored_itf = options[:errored_itf] # Array of id
        @errored_ews = options[:errored_ews] # Array of id
        @from = options[:from]
        @to = options[:to]
        @environment = options[:environment]
      end

      def notify!
        notifier = ClaimsApi::Slack::Client.new(webhook_url: Settings.claims_api.slack.webhook_url,
                                                channel: '#api-benefits-claims-alerts',
                                                username: 'Failed Submissions Messenger')

        notifier.notify('fallback text', blocks: build_blocks)
      end

      private

      def build_blocks
        blocks = []
        blocks << message_heading
        title_to_errors = {
          'Unresolved Disability Compensation Submissions' => @unresolved_errored_claims,
          'Power of Attorney' => @errored_poa,
          'Intent to File' => @errored_itf,
          'Evidence Waiver' => @errored_ews
        }

        title_to_errors.each do |title, errors|
          blocks << build_error_blocks(title, errors)
        end

        blocks.compact.flatten
      end

      def message_heading
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: "*ERRORED SUBMISSIONS*\n\n#{@from} – #{@to}\nThe following submissions have encountered errors " \
                  "in *#{@environment}*:"
          }
        }
      end

      def build_error_blocks(title, errors)
        return nil if errors.nil? || errors.count.zero?

        blocks = [
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: "*#{title} Errors*\nTotal: #{errors.count}"
            }
          }
        ]

        return blocks if title == 'Intent to File'

        errors.each_slice(5) do |errors_slice|
          blocks << build_error_block(title, errors_slice)
        end

        blocks
      end

      def build_error_block(title, errors)
        text = if title == 'Unresolved Disability Compensation Submissions'
                 errors.map do |claim_info|
                   source = claim_info[:is_va_gov] ? 'VA.gov' : 'Non-VA.gov'
                   "TID: #{link_value(claim_info[:transaction_id])} | Source: #{source}"
                 end.join("\n")
               else
                 errors.join("\n")
               end

        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: "```#{text}```"
          }
        }
      end

      def link_value(id, type = :eid)
        id = extract_tag_from_whitelist(id) if type == :tid
        return "<https://vagov.ddog-gov.com/logs?query='N/A'|N/A>" if id.blank?

        time_stamps = datadog_timestamps

        "<https://vagov.ddog-gov.com/logs?query='#{id}'&agg_m=count&agg_m_source=base&agg_t=count&cols=" \
          'host%2Cservice&fromUser=true&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=' \
          "desc&viz=stream&from_ts=#{time_stamps[0]}&to_ts=#{time_stamps[1]}&live=true|#{id}>"
      end

      # set the range to go back 3 days.  Link is based on an ID so any additional range should
      # not add additional noise, but this covers the weekend for Monday morning links
      def datadog_timestamps
        current = Time.now.to_i * 1000 # Data dog uses milliseconds
        three_days_ago = current - 259_200_000 # Three days ago

        [three_days_ago, current]
      end

      # TID value is more a string blob of various data that follows this format (including quotes):
      # 'Form526Submission_3443656, user_uuid: [filtered], service_provider: lighthouse'
      # The KV-looking stuff isn't useful in a DD link, so extract the "tag" at the beginning of the string
      def extract_tag_from_whitelist(id)
        return nil if TID_SUBSTRING_WHITELIST.none? { |s| id&.upcase&.include? s }

        # Not scanning for beginning single quote in case it's not there
        id.split(',').first.scan(/[a-zA-Z0-9_-]+/)[0]
      end
    end
  end
end
