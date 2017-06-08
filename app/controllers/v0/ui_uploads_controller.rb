# frozen_string_literal: true
module V0
  class UiUploadsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      upload = UITest::Document.new.start!(params['file'].tempfile)

      render json: {
        job_id: upload[:job_id],
        confirmation_code: upload[:job_id],
        size: upload[:file].size,
        name: params['file'].original_filename
      }
    end
  end
end
