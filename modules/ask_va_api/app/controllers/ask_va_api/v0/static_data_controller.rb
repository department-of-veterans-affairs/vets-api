# frozen_string_literal: true

module AskVAApi
  module V0
    class StaticDataController < ApplicationController
      skip_before_action :authenticate
      around_action :handle_exceptions, only: %i[categories]
      before_action :get_categories, only: [:categories]

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
        render json: @categories.payload, status: @categories.status
      end

      private

      def get_categories
        categories_data = Categories::Retriever.new.call
        serialized_data = Categories::Serializer.new(categories_data).serializable_hash
        @categories = Result.new(payload: serialized_data, status: :ok)
      end

      Result = Struct.new(:payload, :status, keyword_init: true)
    end
  end
end
