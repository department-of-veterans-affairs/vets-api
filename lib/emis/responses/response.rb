# frozen_string_literal: true

module EMIS
  module Responses
    class Response
      def initialize(raw_response)
        @root = raw_response.body
      end

      def items
        locate(item_tag_name).map do |el|
          build_item(el)
        end
      end

      def ok?
        locate_one('essResponseCode')&.nodes&.first == 'Success'
      end

      def cache?
        ok?
      end

      def error?
        locate_one('essResponseCode')&.nodes&.first == 'ERROR'
      end

      def error
        return nil unless error?

        code = locate_one('code')&.nodes&.first
        text = locate_one('text')&.nodes&.first
        ess_text = locate_one('essText')&.nodes&.first

        EMIS::Errors::ServiceError.new("#{code} #{text} #{ess_text}")
      end

      def empty?
        locate_one('essResponseCode')&.nodes&.first.nil?
      end

      def locate(tag_without_namespace, el = @root)
        find_all_elements_by_tag_name(tag_without_namespace, el, skip_el: true)
      end

      protected

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

      def build_item_value(el, tag, field_name, model)
        value = locate_one(tag, el)
        if value
          value = value.nodes[0]
          model[field_name] = value unless value.is_a?(Ox::Element)
        end
      end

      def locate_one(tag_without_namespace, el = @root)
        locate(tag_without_namespace, el).first
      end

      #
      # This bit of unpleasantness is because the SOAP responses from eMIS have
      # a separate namespace FOR EVERY SINGLE TAG. It's not possible to find all the tags
      # of a specific type, since Ox also doesn't support real XPath and therefore doesn't
      # allow wildcards on parts of the tag. So this finds all of the elements and caches
      # them by tag so that later we can pull those tags out by a regex that ignores the
      # namespaces. For extra fun, the casing is sometimes different for the tags, so we must
      # do a case-insensitive regex.
      #
      def find_all_elements_by_tag_name(tag_without_namespace, el, skip_el: false)
        [].tap do |result|
          if !skip_el && el.respond_to?(:value)
            result << el if el.value =~ /^NS\d+:#{tag_without_namespace}$/i
          end

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
