# frozen_string_literal: true

module AskVAApi
  module V0
    class StaticDataController < ApplicationController
      skip_before_action :authenticate
      around_action :handle_exceptions, except: %i[index]

      def index
        service = Crm::Service.new(icn: 'a')
        data = service.call(endpoint: 'topics')
        render json: data.to_json, status: :ok
      end

      def categories
        get_resource('categories', user_mock_data: params[:user_mock_data])
        render json: @categories.payload, status: @categories.status
      end

      def provinces
        get_resource('provinces', service: mock_service)
        render json: @provinces.payload, status: @provinces.status
      end

      def states
        get_resource('states', service: mock_service)
        render json: @states.payload, status: @states.status
      end

      def subtopics
        get_resource('sub_topics', topic_id: params[:topic_id], user_mock_data: params[:user_mock_data])
        render json: @sub_topics.payload, status: @sub_topics.status
      end

      def topics
        get_resource('topics', category_id: params[:category_id], user_mock_data: params[:user_mock_data])
        render json: @topics.payload, status: @topics.status
      end

      def zipcodes
        get_resource('zipcodes', zip: params[:zipcode], service: mock_service)
        render json: @zipcodes.payload, status: @zipcodes.status
      end

      private

      def get_resource(resource_type, options = {})
        camelize_resource = resource_type.camelize
        retriever_class = "AskVAApi::#{camelize_resource}::Retriever".constantize
        serializer_class = "AskVAApi::#{camelize_resource}::Serializer".constantize
        data = retriever_class.new(**options).call
        serialized_data = serializer_class.new(data).serializable_hash
        instance_variable_set("@#{resource_type}", Result.new(payload: serialized_data, status: :ok))
      end

      def mock_service
        DynamicsMockService.new(icn: nil, logger: nil) if params[:mock]
      end

      Result = Struct.new(:payload, :status, keyword_init: true)
    end
  end
end
