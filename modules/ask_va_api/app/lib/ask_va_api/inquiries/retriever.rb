# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class InquiriesRetrieverError < StandardError; end

    class Retriever < BaseRetriever
      attr_reader :icn

      def initialize(icn: nil, **args)
        super(**args)
        @icn = icn
      end

      def fetch_by_id(id:)
        inquiry_data = fetch_data(id)
        correspondences = fetch_correspondences(inquiry_id: id)
        entity_class.new(inquiry_data.first, correspondences)
      rescue => e
        ::ErrorHandler.handle_service_error(e)
      end

      private

      def fetch_correspondences(inquiry_id:)
        correspondences = Correspondences::Retriever.new(
          inquiry_id:,
          user_mock_data:,
          entity_class: AskVAApi::Correspondences::Entity
        ).call

        correspondences.is_a?(String) ? [] : correspondences
      end

      def fetch_data(id = nil)
        data = user_mock_data ? fetch_mock_data(id) : fetch_crm_data(id)
        enrich_with_category_name(data)
      end

      def fetch_mock_data(id)
        data = File.read('modules/ask_va_api/config/locales/get_inquiries_mock_data.json')
        mock_data = JSON.parse(data, symbolize_names: true)[:Data]
        filter_data(mock_data, id)
      end

      def filter_data(data, id = nil)
        data.select { |inq| id ? inq[:InquiryNumber] == id : inq[:Icn] == icn }
      end

      def fetch_crm_data(id)
        id ||= icn
        endpoint = 'inquiries'
        payload = { id: }
        response = Crm::Service.new(icn:).call(endpoint:, payload:)
        handle_response_data(response:, error_class: InquiriesRetrieverError)
      end

      def enrich_with_category_name(data)
        categories = fetch_categories
        data.each do |record|
          category_id = record.delete(:CategoryId)
          category_name = find_category_name(category_id, categories)
          record[:CategoryName] = category_name
        end
      end

      def fetch_categories
        if user_mock_data
          file = File.read('modules/ask_va_api/config/locales/static_data.json')
          JSON.parse(file, symbolize_names: true)[:Topics]
        else
          Crm::CacheData.new.call(endpoint: 'Topics', cache_key: 'categories_topics_subtopics')[:Topics]
        end
      end

      def find_category_name(category_id, categories)
        category = categories.find { |topic| topic[:Id] == category_id }
        category[:Name] if category
      end
    end
  end
end
