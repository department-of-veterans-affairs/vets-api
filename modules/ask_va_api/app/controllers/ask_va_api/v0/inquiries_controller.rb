# frozen_string_literal: true

module AskVAApi
  module V0
    class InquiriesController < ApplicationController
      def show
        inquiry = Inquiries::InquiryCreator.new(inquiry_number: params[:inquiry_number]).call
        raise "Record with Inquiry Number: #{params[:inquiry_number]} is invalid." if inquiry.inquiry_number.nil?

        render json: Inquiries::Serializer.new(inquiry).serializable_hash, status: :ok
      rescue => e
        render json: { error: e }, status: :not_found
      end
    end
  end
end
