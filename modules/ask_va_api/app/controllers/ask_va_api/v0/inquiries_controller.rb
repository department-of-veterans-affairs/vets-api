# frozen_string_literal: true

module AskVAApi
  module V0
    class InquiriesController < ApplicationController
      around_action :handle_exceptions
      before_action :get_inquiries_by_icn, only: [:index]
      before_action :get_inquiry_by_id, only: [:show]
      skip_before_action :authenticate, only: %i[unauth_create upload_attachment]
      skip_before_action :verify_authenticity_token, only: %i[unauth_create upload_attachment]

      def index
        render json: @user_inquiries.payload, status: @user_inquiries.status
      end

      def show
        render json: @inquiry.payload, status: @inquiry.status
      end

      def create
        render json: { message: 'success' }, status: :created
      end

      def unauth_create
        response = Inquiries::Creator.new(icn: nil).call(params: inquiry_params)
        render json: { message: response }, status: :created
      end

      def upload_attachment
        uploader = AttachmentUploader.new(params[:attachment])
        result = uploader.call
        render json: { message: result[:message] || result[:error] }, status: result[:status]
      end

      def download_attachment
        render json: get_attachment.payload, status: get_attachment.status
      end

      private

      def inquiry_params
        params.permit(:first_name, :last_name).to_h
      end

      def get_inquiry_by_id
        inq = retriever.fetch_by_id(id: params[:id])

        raise InvalidInquiryError if inq.is_a?(Hash)

        @inquiry = Result.new(payload: Inquiries::Serializer.new(inq).serializable_hash, status: :ok)
      end

      def get_inquiries_by_icn
        inquiries = retriever.fetch_by_icn
        @user_inquiries = Result.new(payload: Inquiries::Serializer.new(inquiries).serializable_hash, status: :ok)
      end

      def get_attachment
        att = Attachments::Retriever.new(id: params[:id], service: mock_service).call

        raise InvalidAttachmentError if att.blank?

        Result.new(payload: Attachments::Serializer.new(att).serializable_hash, status: :ok)
      end

      def mock_service
        DynamicsMockService.new(icn: nil, logger: nil) if params[:mock]
      end

      def retriever
        @retriever ||= Inquiries::Retriever.new(icn: current_user.icn, service: mock_service)
      end

      Result = Struct.new(:payload, :status, keyword_init: true)
      class InvalidInquiryError < StandardError; end
      class InvalidAttachmentError < StandardError; end
    end
  end
end
