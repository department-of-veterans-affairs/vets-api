# frozen_string_literal: true

require_relative 'find_profile_message_helpers'

module MVI
  module Messages
    class FindProfileMessageIcn
      include FindProfileMessageHelpers
      attr_reader :icn

      def initialize(icn)
        @icn = icn
      end

      private

      def build_control_act_process
        el = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
        el << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
      end

      def build_parameter_list
        el = element('parameterList')
        el << element('id', root: '2.16.840.1.113883.4.349', extension: @icn)
      end
    end
  end
end
