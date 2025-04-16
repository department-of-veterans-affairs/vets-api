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
        # Fetch the main inquiry data
        inquiry_data = fetch_data(id)
        raise InquiriesRetrieverError, 'Inquiry data not found' if inquiry_data.empty?

        # Fetch correspondences for the inquiry
        correspondences = fetch_correspondences(inquiry_id: id)

        # Instantiate entity with inquiry and correspondence data
        entity_class.new(inquiry_data.first, correspondences)
      rescue => e
        ::ErrorHandler.handle_service_error(e)
      end

      private

      # Fetch correspondences related to the inquiry
      def fetch_correspondences(inquiry_id:)
        correspondences = Correspondences::Retriever.new(
          inquiry_id:,
          user_mock_data:,
          entity_class: AskVAApi::Correspondences::Entity
        ).call

        # Return an empty array if correspondences fetch fails or is invalid
        correspondences.is_a?(String) ? [] : correspondences
      end

      # Fetch inquiry data, either mock or from CRM
      def fetch_data(id = nil)
        inquiries_data = user_mock_data ? fetch_mock_data(id) : fetch_crm_data(id)
        enrich_with_category_name(inquiries_data)
      end

      # Fetch mock inquiry data
      def fetch_mock_data(id)
        file_path = 'modules/ask_va_api/config/locales/get_inquiries_mock_data.json'
        file_data = File.read(file_path)
        mock_data = JSON.parse(file_data, symbolize_names: true)[:Data]
        filter_data(mock_data, id)
      rescue => e
        raise InquiriesRetrieverError, "Failed to fetch mock data: #{e.message}"
      end

      # Filter inquiry data based on ID or ICN
      def filter_data(data, id = nil)
        data.select { |inquiry| id ? inquiry[:InquiryNumber] == id : inquiry[:Icn] == icn }
      end

      # Fetch inquiry data from CRM
      def fetch_crm_data(id)
        endpoint = 'inquiries'
        payload = id ? { inquiryNumber: id } : {}
        response = Crm::Service.new(icn:).call(endpoint:, payload:)
        handle_response_data(response:, error_class: InquiriesRetrieverError)
      end

      # Add category name to each inquiry based on category ID
      def enrich_with_category_name(inquiries_data)
        categories = fetch_categories
        inquiries_data.each do |record|
          category_id = record.delete(:CategoryId)
          record[:CategoryName] = find_category_name(category_id, categories)
        end
      end

      # Fetch categories from cache or static data
      def fetch_categories
        if user_mock_data
          fetch_mock_categories
        else
          Crm::CacheData.new.call(endpoint: 'Topics', cache_key: 'categories_topics_subtopics')[:Topics] || []
        end
      rescue => e
        raise InquiriesRetrieverError, "Failed to fetch categories: #{e.message}"
      end

      # Fetch mock categories from static file
      def fetch_mock_categories
        file_path = 'modules/ask_va_api/config/locales/static_data.json'
        file_data = File.read(file_path)
        JSON.parse(file_data, symbolize_names: true)[:Topics]
      rescue => e
        raise InquiriesRetrieverError, "Failed to fetch mock categories: #{e.message}"
      end

      # Find category name by ID
      def find_category_name(category_id, categories)
        category = categories.find { |topic| topic[:Id] == category_id }
        category ? category[:Name] : nil
      end
    end
  end
end
