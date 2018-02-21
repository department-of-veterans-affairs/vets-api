# frozen_string_literal: true

require 'ox'
require_relative 'message_builder'
require_relative 'find_candidate_message_error'

module MVI
  module Messages
    module FindProfileMessageHelpers
      include MVI::Messages::MessageBuilder
      EXTENSION = 'PRPA_IN201305UV02'

      def to_xml(opt = {})
        super(EXTENSION, build_body)
      rescue => e
        Rails.logger.error "failed to build find candidate message: #{e.message}"
        raise
      end

      private

      def build_body(opt)
        body = build_control_act_process
        body << query_by_parameter
        body
      end

      def query_by_parameter(opt)
        build_query_by_parameter << build_parameter_list
      end

      def build_query_by_parameter(opt)
        modify_code = "MVI.COMP#{opt[:historical_icns] ? '2' : '1'}"

        el = element('queryByParameter')
        el << element('queryId', root: '1.2.840.114350.1.13.28.1.18.5.999', extension: '18204')
        el << element('statusCode', code: 'new')
        el << element('modifyCode', code: modify_code)
        el << element('initialQuantity', value: 1)
      end
    end
  end
end
