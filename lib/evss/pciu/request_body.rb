# frozen_string_literal: true

module EVSS
  module PCIU
    class RequestBody
      attr_reader :request_attrs, :pciu_key, :date_attr

      def initialize(request_attrs, pciu_key:, date_attr: 'effective_date')
        @request_attrs = request_attrs
        @pciu_key = pciu_key
        @date_attr = date_attr
      end

      # Adjusts the passed request attributes to be formatted for an EVSS
      # POST or PUT request body.
      #
      # @return [String] Returns a string of JSON, nested in the passed pciu_key.
      # @example Here is a parsed version of the returned JSON:
      #   {
      #     'cnpPhone' => {
      #       'countryCode' => '1',
      #       'number' => '4445551212',
      #       'extension' => '101',
      #       'effectiveDate' => '2018-04-02T16:01:50+00:00'
      #     }
      #   }
      #
      def set
        set_effective_date
        remove_empty_attrs
        convert_to_json
      end

      private

      # rubocop:disable Style/DateTime
      def set_effective_date
        request_attrs.tap { |instance| instance[date_attr] = DateTime.now.utc }
      end
      # rubocop:enable Style/DateTime

      def remove_empty_attrs
        @request_attrs = request_attrs.as_json.delete_if { |_k, v| v.blank? }
      end

      def convert_to_json
        {
          pciu_key => Hash[
            request_attrs.as_json.map { |k, v| [k.camelize(:lower), v] }
          ]
        }.to_json
      end
    end
  end
end
