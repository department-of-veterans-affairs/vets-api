# frozen_string_literal: true

module FormTransformers
  module BenefitsDiscovery
    class BaseTransformer
      attr_reader :form

      def initialize(form_data)
        @form = parse_form_data(form_data)
      end

      def transform
        raise NotImplementedError, 'Subclasses must implement transform method'
      end

      private

      def parse_form_data(form_data)
        return {} if form_data.nil?
        return form_data if form_data.is_a?(Hash)

        JSON.parse(form_data)
      rescue JSON::ParserError => e
        raise ArgumentError, "Invalid JSON form data: #{e.message}"
      end
    end
  end
end
