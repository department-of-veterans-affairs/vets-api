# frozen_string_literal: true

require 'emis/errors/service_error'

module EMIS
  module Responses
    # Generic EMIS response wrapper used to translate the XML data
    # into a model object
    class Response
      # @param raw_response [Faraday::Env] Faraday response object
      def initialize(raw_response)
        @root = raw_response.body
      end

      # @return [EMIS::Models] Response translated into array of
      #  +model_class+
      def items
        locate(item_tag_name).map do |el|
          build_item(el)
        end
      end

      # @return [Boolean] true if response code was successful
      def ok?
        locate_one('essResponseCode')&.nodes&.first == 'Success'
      end

      # (see EMIS::Responses::Response#ok?)
      def cache?
        ok?
      end

      # @return [Boolean] true if response code had an error
      def error?
        locate_one('essResponseCode')&.nodes&.first == 'ERROR'
      end

      # @return [EMIS::Errors::ServiceError] Translates XML error data
      #  into an error class
      def error
        return nil unless error?

        code = locate_one('code')&.nodes&.first
        text = locate_one('text')&.nodes&.first
        ess_text = locate_one('essText')&.nodes&.first

        EMIS::Errors::ServiceError.new("#{code} #{text} #{ess_text}")
      end

      # @return [Boolean] true if data set is empty
      def empty?
        locate_one('essResponseCode')&.nodes&.first.nil?
      end

      # Locate elements from root element by tag name
      # @param tag_without_namespace [String] XML tag name without namespace
      # @param el [Ox::Document] Root element to search from
      # @return [Array<Ox::Element>] Elements found
      def locate(tag_without_namespace, el = @root)
        find_all_elements_by_tag_name(tag_without_namespace, el, skip_el: true)
      end

      protected

      # Build model class populated with XML data
      # @param el [Ox::Element] Root XML element
      # @param schema [Hash] Schema for translating XML data to model attributes
      # @param model_class [EMIS::Models] Data model class
      # @return [EMIS::Models] Populated model class
      def build_item(el, schema: item_schema, model_class: self.model_class)
        model_class.new.tap do |model|
          schema.each do |tag, data|
            field_name = data[:rename] || tag.snakecase
            if data[:schema]
              tags = locate(tag, el)
              model[field_name] = tags.map { |t| build_item(t, schema: data[:schema], model_class: data[:model_class]) }
            else
              build_item_value(el, tag, field_name, model)
            end
          end
        end
      end

      # Set an attribute of a model class with XML data
      # @param el [Ox::Element] XML element
      # @param tag [String] XML tag name
      # @param field_name [String] Model setter name
      # @param model [EMIS::Models] Model class
      def build_item_value(el, tag, field_name, model)
        value = locate_one(tag, el)
        if value
          value = value.nodes[0]
          model[field_name] = value unless value.is_a?(Ox::Element)
        end
      end

      # Locate one element from root element by tag name
      # @param tag_without_namespace [String] XML tag name without namespace
      # @param el [Ox::Document] Root element to search from
      # @return [Ox::Element] Element found
      def locate_one(tag_without_namespace, el = @root)
        locate(tag_without_namespace, el).first
      end

      # Finds elements by XML tag name
      # @param tag_without_namespace [String] XML tag name without namespace
      # @param el [Ox::Document] Root element to search from
      # @param skip_el [Boolean] Skip root element in results if true
      # @return [Array<Ox::Element>] Elements found
      def find_all_elements_by_tag_name(tag_without_namespace, el, skip_el: false)
        #
        # This bit of unpleasantness is because the SOAP responses from eMIS have
        # a separate namespace FOR EVERY SINGLE TAG. It's not possible to find all the tags
        # of a specific type, since Ox also doesn't support real XPath and therefore doesn't
        # allow wildcards on parts of the tag. So this finds all of the elements and caches
        # them by tag so that later we can pull those tags out by a regex that ignores the
        # namespaces. For extra fun, the casing is sometimes different for the tags, so we must
        # do a case-insensitive regex.
        #
        [].tap do |result|
          result << el if !skip_el && el.respond_to?(:value) && el.value.match?(/^NS\d+:#{tag_without_namespace}$/i)

          if el.respond_to?(:nodes)
            el.nodes.each do |node|
              result.concat(find_all_elements_by_tag_name(tag_without_namespace, node, skip_el: false))
            end
          end
        end
      end
    end
  end
end
