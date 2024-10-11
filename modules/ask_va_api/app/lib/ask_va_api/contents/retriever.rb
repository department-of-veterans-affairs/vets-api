# frozen_string_literal: true

module AskVAApi
  module Contents
    class Retriever < BaseRetriever
      VALID_TYPES = %w[category topic subtopic].freeze

      class InvalidTypeError < StandardError; end

      def initialize(type:, parent_id: nil, **args)
        super(**args)
        @type = type
        @parent_id = parent_id
        validate_type!
      end

      private

      def fetch_data
        data = user_mock_data ? static_data : fetch_from_cache
        filter_data(data)
      end

      def static_data
        @static_data ||= begin
          static = File.read('modules/ask_va_api/config/locales/static_data.json')
          JSON.parse(static, symbolize_names: true)
        end
      end

      def fetch_from_cache
        Crm::CacheData.new.call(endpoint: 'Topics', cache_key: 'categories_topics_subtopics')
      end

      def filter_data(data)
        return [] if data[:Topics].blank?

        case @type
        when 'category'
          filter_categories(data)
        when 'topic', 'subtopic'
          filter_topics_or_subtopics(data)
        end
      end

      def filter_categories(data)
        data[:Topics]
          .select { |t| t[:ParentId].nil? }
          .sort_by { |cat| cat[:RankOrder] }
      end

      def filter_topics_or_subtopics(data)
        data[:Topics]
          .select { |topic| topic[:ParentId] == @parent_id }
          .sort_by { |topic| topic[:Name] }
      end

      def validate_type!
        raise InvalidTypeError, "Invalid type: #{@type}" unless VALID_TYPES.include?(@type)
      end
    end
  end
end
