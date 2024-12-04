# frozen_string_literal: true

require 'decision_reviews/v1/constants'

module DecisionReviews
  module V1
    module LoggingUtils
      ##
      # Logs formatted information about an appeal.
      #
      # @param key [Symbol] The key to identify the action. Used to construct log message and StatsD prefix.
      # @param user_uuid [String] User's UUID.
      # @param form_id [String] The ID of the form. Must be "10182" (NOD), "20-0995" (SC), or "20-0996" (HLR).
      # @param is_success [Boolean] Whether the action was successful. Used to construct log_level and StatsD suffix.
      # @param upstream_system [String] (optional) The name of the upstream system.
      # @param downstream_system [String] (optional) The name of the downstream system.
      # @param response_error [Object] (optional) The error response object thrown after an unsuccessful HTTP request.
      # @param status_code [Integer] (optional) The status code of the response.
      # @param body [String, Object] (optional) The body of the response.
      # @param params [Hash] Additional parameters to include in the log.
      #
      # @return [void]
      #
      # rubocop:disable Metrics/ParameterLists
      # rubocop:disable Layout/LineLength
      def log_formatted(key:, user_uuid:, form_id:, is_success:, upstream_system: nil, downstream_system: nil, response_error: nil, status_code: nil, body: nil, params: {})
        action = key.to_s.humanize
        result = is_success ? 'success' : 'failure'
        log_level = is_success ? :info : :error
        # The HTTP clients used across VA raise various response error objects with varying interfaces, hence the ORs
        # below. Preference is given to `original_status` and `original_body`, if present, as they represent the status
        # and body returned by the third party service, which is most helpful for logging purposes. It is always
        # possible that the error thrown has nothing to do with the HTTP request, hence the `message` call. Both
        # `status_code` and `body` can be overriden.
        status_code ||= response_error.try(:original_status) || response_error.try(:status_code) || response_error.try(:status)
        body ||= response_error.try(:original_body) || response_error.try(:message)

        StatsD.increment("decision_review.form_#{form_id}.#{key}.#{result}")

        Rails.logger.send(log_level, {
          message: "#{action} #{result}!",
          user_uuid:,
          action:,
          form_id:,
          upstream_system:,
          downstream_system:,
          is_success:,
          http: {
            status_code:,
            body:
          }
        }.merge(params))
      end
      # rubocop:enable Metrics/ParameterLists
      # rubocop:enable Layout/LineLength

      def parse_form412_response_to_log_msg(appeal_submission_id:, data:, uuid: nil, bm: nil)
        log_data = { message: 'Supplemental Claim 4142 submitted.',
                     lighthouse_submission: {
                       id: appeal_submission_id
                     },
                     form_id: FORM4142_ID, parent_form_id: SUPP_CLAIM_FORM_ID,
                     response_body: data.body,
                     response_status: data.status }
        log_data[:extracted_uuid] = extract_uuid_from_central_mail_message(data, uuid) if data.success?
        log_data[:meta] = benchmark_to_log_data_hash(bm) unless bm.nil?
        log_data
      end

      def parse_lighthouse_response_to_log_msg(data:, bm: nil)
        log_data = {
          form_id: SUPP_CLAIM_FORM_ID,
          message: 'Successful Lighthouse Supplemental Claim Submission',
          lighthouse_submission: {
            id: data['id'],
            appeal_type: data['type'],
            attributes: {
              status: data['attributes']['status'],
              updatedAt: data['attributes']['updatedAt'],
              createdAt: data['attributes']['createdAt']
            }
          }
        }
        log_data[:meta] = benchmark_to_log_data_hash(bm) unless bm.nil?
        log_data
      end

      def run_and_benchmark_if_enabled(&block)
        bm = nil
        block_result = nil
        if benchmark?
          bm = Benchmark.measure do
            block_result = block.call
          end
        else
          block_result = block.call
        end
        [block_result, bm]
      end

      ##
      # Takes a block and runs it. If benchmarking is enabled it will benchmark and return the results.
      # Returns a tuple of what the block returns, and either nil (if benchmarking disabled), or the benchmark results
      #
      # @param block [block] block to run
      # @return [result, benchmark]
      #
      def benchmark_to_log_data_hash(bm)
        { benchmark: { user: bm.utime, system: bm.stime, total: bm.total, real: bm.real } }
      end

      private

      def extract_uuid_from_central_mail_message(data, uuid)
        return uuid unless uuid.nil?

        data.body[/(?<=\[).*?(?=\])/].split(': ').last
      end

      def benchmark?
        Settings.decision_review.benchmark_performance
      end
    end
  end
end
