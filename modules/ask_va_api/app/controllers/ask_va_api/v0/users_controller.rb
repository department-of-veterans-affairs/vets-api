# frozen_string_literal: true

module AskVAApi
  module V0
    class UsersController < ApplicationController
      before_action :fetch_user_inquiries, only: [:show]

      def show
        render json: @user_inquiries.payload, status: @user_inquiries.status
      end

      private

      def fetch_user_inquiries
        inquiries = Inquiries::Retriever.new(sec_id: current_user.sec_id).fetch_by_sec_id
        @user_inquiries = Result.new(payload: Inquiries::Serializer.new(inquiries).serializable_hash, status: :ok)
      rescue ErrorHandler::ServiceError, Dynamics::ErrorHandler::ServiceError => e
        log_and_render_error('service_error', e, :unprocessable_entity)
      rescue ArgumentError => e
        log_and_render_error('argument_error', e, :bad_request)
      end

      def log_and_render_error(action, exception, status)
        log_error(action, exception)
        @user_inquiries = Result.new(payload: { error: exception.message }, status:)
      end

      Result = Struct.new(:payload, :status, keyword_init: true)
    end
  end
end
