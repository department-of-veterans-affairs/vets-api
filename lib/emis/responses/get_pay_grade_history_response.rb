# frozen_string_literal: true

require 'emis/models/pay_grade_history'
require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS v2 pay grade history response
    class GetPayGradeHistoryResponse < EMIS::Responses::Response
      # @return [String] XML Tag that contains response data
      def item_tag_name
        'payGradeHistory'
      end

      # @return [Hash] Schema for translating XML data into model data
      def item_schema
        {
          'personnelOrganizationCode' => {},
          'personnelCategoryTypeCode' => {},
          'personnelSegmentIdentifier' => {},
          'payPlanCode' => {},
          'PayGradeCode' => {},
          'serviceRankNameCode' => {},
          'serviceRankNameTxt' => {},
          'payGradeDate' => {}
        }
      end

      # @return [Class] Model class to put response data
      def model_class
        EMIS::Models::PayGradeHistory
      end
    end
  end
end
