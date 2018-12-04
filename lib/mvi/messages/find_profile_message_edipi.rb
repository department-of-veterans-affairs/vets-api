# frozen_string_literal: true

require_relative 'find_profile_message_helpers'

module MVI
  module Messages
    class FindProfileMessageEdipi
      include FindProfileMessageHelpers
      attr_reader :edipi

      def initialize(edipi)
        @edipi = edipi
      end

      private

      def build_control_act_process
        el = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
        el << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
      end

      def build_parameter_list
        el = element('parameterList')
        el << element('id', root: '2.16.840.1.113883.3.42.10001.100001.12', extension: @edipi)
        el << build_vba_orchestration if Settings.mvi.vba_orchestration
        el
      end
    end
  end
end
