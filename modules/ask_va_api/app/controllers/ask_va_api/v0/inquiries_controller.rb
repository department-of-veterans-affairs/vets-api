# frozen_string_literal: true

module AskVAApi
  module V0
    class InquiriesController < ApplicationController
      around_action :handle_exceptions
      skip_before_action :authenticate, only: %i[unauth_create upload_attachment test_create show]
      skip_before_action :verify_authenticity_token, only: %i[unauth_create upload_attachment test_create]

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

      def upload_attachment
        result = Attachments::Uploader.new(convert_keys_to_camel_case(attachment_params)).call
        render json: result.to_json, status: :ok
      end

      def download_attachment
        att = Attachments::Retriever.new(id: params[:id], service: mock_service).call

        raise InvalidAttachmentError if att.blank?

        render json: Attachments::Serializer.new(att).serializable_hash, status: :ok
      end

      def profile
        profile = Profile::Retriever.new(icn: current_user.icn, user_mock_data: params[:user_mock_data]).call
        render json: Profile::Serializer.new(profile).serializable_hash, status: :ok
      end

      def status
        stat = Inquiries::Status::Retriever.new(icn: current_user.icn).call(inquiry_number: params[:id])
        render json: Inquiries::Status::Serializer.new(stat).serializable_hash, status: :ok
      end

      def create_reply
        response = Correspondences::Creator.new(message: params[:reply], inquiry_id: params[:id], service: nil).call
        render json: response.to_json, status: :ok
      end

      private

      def process_inquiry(icn = current_user.icn)
        Inquiries::Creator.new(icn:).call(payload: inquiry_params)
      end

      def retriever(icn: current_user.icn)
        entity_class = AskVAApi::Inquiries::Entity
        @retriever ||= Inquiries::Retriever.new(icn:, user_mock_data: params[:mock], entity_class:)
      end

      def convert_keys_to_camel_case(params)
        hash = I18n.t('ask_va_api.parameters.attachment')
        params.each_with_object({}) do |(key, value), new_hash|
          new_key = hash[key.to_sym]
          new_hash[new_key.to_sym] = value
        end
      end

      def mock_service
        DynamicsMockService.new(icn: nil, logger: nil) if params[:mock]
      end

      def attachment_params
        params.permit(fetch_parameters('attachment')).to_h
      end

      def inquiry_params
        params.permit(
          *fetch_parameters('base'),
          *fetch_parameters('dependant'),
          *fetch_parameters('submitter'),
          *fetch_parameters('veteran'),
          SchoolObj: fetch_parameters('school')
        ).to_h
      end

      def fetch_parameters(key)
        I18n.t("ask_va_api.parameters.#{key}").keys
      end

      class InvalidAttachmentError < StandardError; end
    end
  end
end
