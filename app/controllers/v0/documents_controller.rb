# frozen_string_literal: true
module V0
  class DocumentsController < ApplicationController
    skip_before_action :authenticate

    def create
      params.require :file
      uploaded_io = params[:file]
      claim_id = params[:claim_id]
      tracked_item_id = params[:tracked_item]

      current_user.upload_document(uploaded_io.original_filename, uploaded_io.read, claim_id, tracked_item_id)
      head :no_content
    end

    private

    def current_user
      @current_user ||= User.sample_claimant
    end
  end
end
