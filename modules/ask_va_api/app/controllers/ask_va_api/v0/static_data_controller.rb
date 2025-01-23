# frozen_string_literal: true

require 'brd/brd'

module AskVAApi
  module V0
    class StaticDataController < ApplicationController
      skip_before_action :authenticate
      around_action :handle_exceptions, except: %i[test_endpoint]

      def test_endpoint
        data = Crm::Service.new(icn: nil).call(endpoint: params[:endpoint], payload: params[:payload] || {})
        render json: data.to_json, status: :ok
      end

      def announcements
        get_resource('announcements', user_mock_data: params[:user_mock_data])
        render_result(@announcements)
      end

      def branch_of_service
        get_resource('branch_of_service', user_mock_data: params[:user_mock_data])
        render_result(@branch_of_service)
      end

      def contents
        get_resource('contents',
                     user_mock_data: params[:user_mock_data],
                     type: params[:type],
                     parent_id: params[:parent_id])

        render_result(@contents)
      end

      def states
        get_resource('states', service: mock_service)
        render_result(@states)
      end

      def zipcodes
        get_resource('zipcodes', zip: params[:zipcode], service: mock_service)
        render_result(@zipcodes)
      end

      private

      def get_resource(resource_type, options = {})
        camelize_resource = resource_type.camelize
        retriever_class = constantize_class("AskVAApi::#{camelize_resource}::Retriever")
        serializer_class = constantize_class("AskVAApi::#{camelize_resource}::Serializer")
        entity_class = constantize_class("AskVAApi::#{camelize_resource}::Entity")

        options.merge!(entity_class:) unless %w[provinces states zipcodes].include?(resource_type)

        data = retriever_class.new(**options).call

        serialized_data = serializer_class.new(data).serializable_hash
        instance_variable_set("@#{resource_type}", Result.new(payload: serialized_data, status: :ok))
      end

      def constantize_class(class_name)
        class_name.constantize
      end

      def mock_service
        DynamicsMockService.new(icn: nil, logger: nil) if params[:user_mock_data]
      end

      def render_result(resource)
        render json: resource.payload, status: resource.status
      end
      Result = Struct.new(:payload, :status, keyword_init: true)
    end
  end
end
