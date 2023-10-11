# frozen_string_literal: true

module AskVAApi
  module V0
    class StaticDataController < ApplicationController
      skip_before_action :authenticate
      around_action :handle_exceptions, only: %i[
        categories
        states
        subtopics
        topics
        zipcodes
      ]

      def index
        data = {
          Emily: { 'data-info' => 'emily@oddball.io' },
          Eddie: { 'data-info' => 'eddie.otero@oddball.io' },
          Jacob: { 'data-info' => 'jacob@docme360.com' },
          Joe: { 'data-info' => 'joe.hall@thoughtworks.com' },
          Khoa: { 'data-info' => 'khoa.nguyen@oddball.io' }
        }
        render json: data, status: :ok
      rescue => e
        service_exception_handler(e)
      end

      def categories
        get_resource('categories')
        render json: @categories.payload, status: @categories.status
      end

      def states
        get_resource('states')
        render json: @states.payload, status: @states.status
      end

      def subtopics
        get_resource('sub_topics', topic_id: params[:topic_id])
        render json: @sub_topics.payload, status: @sub_topics.status
      end

      def topics
        get_resource('topics', category_id: params[:category_id])
        render json: @topics.payload, status: @topics.status
      end

      def zipcodes
        get_resource('zipcodes', zip: params[:zipcode])
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

      Result = Struct.new(:payload, :status, keyword_init: true)
    end
  end
end
