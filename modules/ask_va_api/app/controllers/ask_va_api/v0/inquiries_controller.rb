# frozen_string_literal: true

module AskVAApi
  module V0
    class InquiriesController < ApplicationController
      around_action :handle_exceptions
      skip_before_action :authenticate, only: %i[unauth_create status]
      skip_before_action :verify_authenticity_token, only: %i[unauth_create]

      def index
        inquiries = retriever.call
        render json: Inquiries::Serializer.new(inquiries).serializable_hash, status: :ok
      end

      def show
        inq = retriever.fetch_by_id(id: params[:id])
        render json: Inquiries::Serializer.new(inq).serializable_hash, status: :ok
      end

      def create
        render json: process_inquiry.to_json, status: :created
      end

      def unauth_create
        render json: process_inquiry.to_json, status: :created
      end

      def download_attachment
        entity_class = Attachments::Entity
        att = Attachments::Retriever.new(
          icn: current_user.icn,
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
        response = Correspondences::Creator.new(params: reply_params, inquiry_id: params[:id], service: nil).call
        render json: response.to_json, status: :ok
      end

      private

      def process_inquiry
        Inquiries::Creator.new(user: current_user).call(inquiry_params:)
      end

      def retriever(icn: current_user.icn)
        entity_class = AskVAApi::Inquiries::Entity
        @retriever ||= Inquiries::Retriever.new(icn:, user_mock_data: params[:user_mock_data], entity_class:)
      end

      def mock_service
        DynamicsMockService.new(icn: nil, logger: nil) if params[:mock]
      end

      def inquiry_params
        params.require(:inquiry).permit(
          *fetch_parameters('fields'),
          pronouns: fetch_parameters('nested_fields.pronouns'),
          address: fetch_parameters('nested_fields.address'),
          about_yourself: fetch_parameters('nested_fields.about_yourself'),
          about_the_veteran: fetch_parameters('nested_fields.about_the_veteran'),
          about_the_family_member: fetch_parameters('nested_fields.about_the_family_member'),
          state_or_residency: fetch_parameters('nested_fields.state_or_residency'),
          files: fetch_parameters('nested_fields.files'),
          school_obj: fetch_parameters('nested_fields.school_obj')
        ).to_h
      end

      def reply_params
        params.permit(
          :reply,
          files: fetch_parameters('nested_fields.files')
        ).to_h
      end

      def fetch_parameters(key)
        I18n.t("ask_va_api.parameters.inquiry.#{key}")
      end

      class InvalidAttachmentError < StandardError; end
    end
  end
end
