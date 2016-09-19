# frozen_string_literal: true
require 'va/api/common/exceptions/parameter_missing'

module V0
  class DocumentsController < ApplicationController
    skip_before_action :authenticate

    def create
      params.require :file
      uploaded_io = params[:file]
      claim_id = params[:claim_id]
      tracked_item_id = params[:tracked_item]

      Claim.upload_document(claim_id,
                            uploaded_io.original_filename, uploaded_io.read,
                            tracked_item_id, current_user)
      head :no_content

    rescue ActionController::ParameterMissing => ex
      raise VA::API::Common::Exceptions::ParameterMissing, ex.param
    end

    private

    def current_user
      @current_user ||= User.sample_claimant
    end
  end
end
