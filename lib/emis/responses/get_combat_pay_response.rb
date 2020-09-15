# frozen_string_literal: true

require 'emis/models/deployment'
require 'emis/models/deployment_location'
require_relative 'response'

module EMIS
  module Responses
    # EMIS combat pay response
    class GetCombatPayResponse < EMIS::Responses::Response
      # @return [String] XML Tag that contains response data
      def item_tag_name
        'combatPay'
      end

      # @return [Hash] Schema for translating XML data into model data
      def item_schema
        {
          'combatPaySegmentIdentifier' => { rename: 'segment_identifier' },
          'combatPayBeginDate' => { rename: 'begin_date' },
          'combatPayEndDate' => { rename: 'end_date' },
          'combatPayTypeCode' => { rename: 'type_code' },
          'combatZoneCountryCode' => {}
        }
      end

      # @return [Class] Model class to put response data
      def model_class
        EMIS::Models::CombatPay
      end
    end
  end
end
