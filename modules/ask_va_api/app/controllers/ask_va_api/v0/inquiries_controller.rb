# frozen_string_literal: true

module AskVAApi
  module V0
    class InquiriesController < ApplicationController
      before_action :get_inquiries_by_sec_id, only: [:index]
      before_action :get_inquiry_by_inquiry_number, only: [:show]

      def index
        render json: @user_inquiries.payload, status: @user_inquiries.status
      end

      def show
        render json: @inquiry.payload, status: @inquiry.status
      end

      private

      def handle_exceptions
        yield
      rescue InvalidInquiryError, ArgumentError => e
        log_and_render_error('invalid_inquiry_error', e, :bad_request)
      rescue ErrorHandler::ServiceError, Dynamics::ErrorHandler::ServiceError => e
        log_and_render_error('service_error', e, :unprocessable_entity)
      end

      def get_inquiry_by_inquiry_number
        handle_exceptions do
          inq = retriever.fetch_by_inquiry_number(inquiry_number: params[:inquiry_number])
          raise InvalidInquiryError if inq.inquiry_number.nil?

          @inquiry = Result.new(payload: Inquiries::Serializer.new(inq).serializable_hash, status: :ok)
        end
      end

      def get_inquiries_by_sec_id
        handle_exceptions do
          inquiries = retriever.fetch_by_sec_id
          @user_inquiries = Result.new(payload: Inquiries::Serializer.new(inquiries).serializable_hash, status: :ok)
        end
      end

      def retriever
        @retriever ||= Inquiries::Retriever.new(sec_id: current_user.account.sec_id)
      end

      def log_and_render_error(action, exception, status)
        log_error(action, exception)
        render json: { error: exception.message }, status:
      end

      Result = Struct.new(:payload, :status, keyword_init: true)
      class InvalidInquiryError < StandardError; end
    end
  end
end
