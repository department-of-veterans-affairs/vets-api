# frozen_string_literal: true

module ClaimsApi
    class Form2122
      attr_accessor :attributes
  
      def initialize(params = {})
        @attributes = params
      end
  
      def to_internal
        # TODO output to either XML or JSON BGS format
        {
          "bgs": attributes
        }.to_json
      end
    end
  end
  