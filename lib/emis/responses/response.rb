# frozen_string_literal: true
require 'ostruct'

module EMIS
  module Responses
    class Response
      def initialize(raw_response)
        @root = raw_response.body
      end

      def ok?
        locate_one('essResponseCode')&.nodes&.first == 'Success'
      end

      def error?
        locate_one('essResponseCode')&.nodes&.first == 'ERROR'
      end

      def empty?
        locate_one('essResponseCode')&.nodes&.first == nil
      end

      def locate(tag_without_namespace, el = @root)
        find_all_elements_by_tag_name(tag_without_namespace, el)
      end

      protected

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
      def find_all_elements_by_tag_name(tag_without_namespace, el)
        [].tap do |result|
          if el.respond_to?(:value)
            result << el if el.value =~ /^NS\d+:#{tag_without_namespace}$/i
          end

          if el.respond_to?(:nodes)
            el.nodes.each do |node|
              result.concat(find_all_elements_by_tag_name(tag_without_namespace, node))
            end
          end
        end
      end
    end
  end
end
