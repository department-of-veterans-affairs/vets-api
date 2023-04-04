# frozen_string_literal: true

require 'decision_review_v1/utilities/constants'

module DecisionReviewV1
  module Appeals
    module Helpers
      def get_and_rejigger_required_info(request_body:, form4142:, user:)
        data = request_body['data']
        attrs = data['attributes']
        vet = attrs['veteran']
        x = {
          "vaFileNumber": user.ssn.to_s.strip.presence,
          "veteranSocialSecurityNumber": user.ssn.to_s.strip.presence,
          "veteranFullName": {
            "first": user.first_name.to_s.strip.first(12),
            "middle": middle_initial(user),
            "last": user.last_name.to_s.strip.first(18).presence
          },
          "veteranDateOfBirth": user.birth_date.to_s.strip.presence,
          "veteranAddress": vet['address'].merge('country' => vet['address']['countryCodeISO2']),
          "email": vet['email'],
          "veteranPhone": "#{vet['phone']['areaCode']}#{vet['phone']['phoneNumber']}"
        }
        x.merge(form4142).deep_stringify_keys
      end

      def create_supplemental_claims_headers(user)
        headers = {
          'X-VA-SSN' => user.ssn.to_s.strip.presence,
          'X-VA-ICN' => user.icn.presence,
          'X-VA-First-Name' => user.first_name.to_s.strip.first(12),
          'X-VA-Middle-Initial' => middle_initial(user),
          'X-VA-Last-Name' => user.last_name.to_s.strip.first(18).presence,
          'X-VA-Birth-Date' => user.birth_date.to_s.strip.presence
        }.compact

        missing_required_fields = SC_REQUIRED_CREATE_HEADERS - headers.keys
        if missing_required_fields.present?
          e = Common::Exceptions::Forbidden.new(
            source: "#{self.class}##{__method__}",
            detail: { missing_required_fields: }
          )
          raise e
        end

        headers
      end

      def benchmark?
        Settings.decision_review.benchmark_performance
      end

      ##
      # Takes a block and runs it. If benchmarking is enabled it will benchmark and return the results.
      # Returns a tuple of what the block returns, and either nil (if benchmarking disabled), or the benchmark results
      #
      # @param block [block] block to run
      # @return [result, benchmark]
      #
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

      def benchmark_to_log_data_hash(bm)
        { benchmark: { user: bm.utime, system: bm.stime, total: bm.total, real: bm.real } }
      end

      def extract_uuid_from_central_mail_message(data)
        data.body[/(?<=\[).*?(?=\])/].split(': ').last
      end

      def parse_form412_response_to_log_msg(appeal_submission_id:, data:, bm: nil)
        log_data = { message: 'Supplemental Claim 4142 submitted.',
                     lighthouse_submission: {
                       id: appeal_submission_id
                     },
                     form_id: FORM4142_ID, parent_form_id: SUPP_CLAIM_FORM_ID,
                     response_body: data.body,
                     response_status: data.status }
        log_data[:extracted_uuid] = extract_uuid_from_central_mail_message(data) if data.success?
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
    end
  end
end
