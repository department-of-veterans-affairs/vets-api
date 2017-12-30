# frozen_string_literal: true
module V0
  module VIC
    class GovtIdAttachmentsController < ApplicationController
      skip_before_action(:authenticate)

      def create
        govt_id_attachment = ::VIC::GovtIdAttachment.new
        govt_id_attachment.set_file_data!(params[:govt_id_attachment][:file_data])
        govt_id_attachment.save!
        render(json: govt_id_attachment)
      end
    end
  end
end
