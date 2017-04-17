# frozen_string_literal: true
require 'emis/responses/response'

module EMIS
  module Responses
    class GetMilitaryOccupationResponse < EMIS::Responses::Response
      def items
        locate('militaryOccupation').map do |el|
          build_item(el)
        end
      end

      private

      def build_item(el)
        OpenStruct.new(
          segment_identifier: locate_one('occupationSegmentIdentifier', el).nodes[0],
          dod_occupation_date: locate_one('dodOccupationDate', el).nodes[0],
          occupation_type: locate_one('occupationType', el).nodes[0],
          service_specific_occupation_type: locate_one('serviceSpecificOccupationType', el).nodes[0],
          service_occupation_date: Date.parse(locate_one('serviceOccupationDate', el).nodes[0])
        )
      end
    end
  end
end
