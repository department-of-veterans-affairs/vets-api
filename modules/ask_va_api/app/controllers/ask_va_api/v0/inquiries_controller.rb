# frozen_string_literal: true

module AskVAApi
  module V0
    class InquiriesController < ApplicationController
      around_action :handle_exceptions
      skip_before_action :authenticate, only: %i[unauth_create upload_attachment status]
      skip_before_action :verify_authenticity_token, only: %i[unauth_create upload_attachment]

      def index
        inquiries = retriever.call
        render json: Inquiries::Serializer.new(inquiries).serializable_hash, status: :ok
      end

      def show
        inq = retriever(icn: nil).fetch_by_id(id: params[:id])
        render json: Inquiries::Serializer.new(inq).serializable_hash, status: :ok
      end

      def create
        render json: process_inquiry.to_json, status: :created
      end

      def unauth_create
        render json: process_inquiry(nil).to_json, status: :created
      end

      def download_attachment
        entity_class = Attachments::Entity
        att = Attachments::Retriever.new(
          id: params[:id],
          service: mock_service,
          user_mock_data: nil,
          entity_class:
        ).call

        raise InvalidAttachmentError if att.blank?

        render json: Attachments::Serializer.new(att).serializable_hash, status: :ok
      end

      def profile
        profile = Profile::Retriever.new(icn: current_user.icn, user_mock_data: params[:user_mock_data]).call
        render json: Profile::Serializer.new(profile).serializable_hash, status: :ok
      end

      def status
        entity_class = Inquiries::Status::Entity
        stat = Inquiries::Status::Retriever.new(user_mock_data: params[:user_mock_data], entity_class:,
                                                inquiry_number: params[:id]).call
        render json: Inquiries::Status::Serializer.new(stat).serializable_hash, status: :ok
      end

      def create_reply
        response = Correspondences::Creator.new(message: params[:reply], inquiry_id: params[:id], service: nil).call
        render json: response.to_json, status: :ok
      end

      private

      def process_inquiry(icn = current_user.icn)
        Inquiries::Creator.new(icn:).call(inquiry_params:)
      end

      def retriever(icn: current_user.icn)
        entity_class = AskVAApi::Inquiries::Entity
        @retriever ||= Inquiries::Retriever.new(icn:, user_mock_data: params[:user_mock_data], entity_class:)
      end

      def mock_service
        DynamicsMockService.new(icn: nil, logger: nil) if params[:mock]
      end

      def inquiry_params
        params.permit(
          *fetch_parameters('inquiry').keys,
          profile: fetch_parameters('profile').keys,
          school_obj: fetch_parameters('school_obj').keys,
          attachments: fetch_parameters('attachments').keys
        ).to_h
      end

      def fetch_parameters(key)
        I18n.t("ask_va_api.parameters.#{key}")
      end

      def resource_path(options)
        v0_inquiries_url(options)
      end

      class InvalidAttachmentError < StandardError; end
    end
  end
end
