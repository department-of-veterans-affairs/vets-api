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

      def upload_attachment
        attachment_translation_map = fetch_parameters('attachment')
        result = Attachments::Uploader.new(
          convert_keys_to_camel_case(attachment_params, attachment_translation_map)
        ).call
        render json: result.to_json, status: :ok
      end

      def download_attachment
        entity_class = Attachments::Entity
        att = Attachments::Retriever.new(id: params[:id], service: mock_service, entity_class:).call

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
        inquiry_translation_map = fetch_parameters('inquiry')
        converted_inquiry_params = convert_keys_to_camel_case(inquiry_params, inquiry_translation_map)
        Inquiries::Creator.new(icn:).call(payload: converted_inquiry_params)
      end

      def retriever(icn: current_user.icn)
        entity_class = AskVAApi::Inquiries::Entity
        @retriever ||= Inquiries::Retriever.new(icn:, user_mock_data: params[:user_mock_data], entity_class:)
      end

      def convert_keys_to_camel_case(params, translation_map)
        params.each_with_object({}) do |(key, value), result_hash|
          if key == 'school_obj'
            school_translation_map = fetch_parameters('school')
            value = convert_keys_to_camel_case(value, school_translation_map)
          end
          camel_case_key = translation_map[key.to_sym]
          result_hash[camel_case_key.to_sym] = value
        end
      end

      def mock_service
        DynamicsMockService.new(icn: nil, logger: nil) if params[:mock]
      end

      def attachment_params
        params.permit(fetch_parameters('attachment').keys).to_h
      end

      def inquiry_params
        params.permit(
          *fetch_parameters('inquiry').keys,
          school_obj: fetch_parameters('school').keys
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
