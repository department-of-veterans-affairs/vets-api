# frozen_string_literal: true

module V0
  class DisabilityCompensationFormsController < ApplicationController
    include FormAttachmentCreate

    before_action { authorize :evss, :access? }

    def rated_disabilities
      response = service.get_rated_disabilities
      render json: response,
             serializer: RatedDisabilitiesSerializer
    end

    def submit
      response = service.submit_form(request.body.string)
      render json: response,
             serializer: SubmitDisabilityFormSerializer
    end

    def upload_ancillary_form
      params.require :file

      document = FormAttachmentCreate.new.create #how does this object work?

      raise Common::Exceptions::ValidationErrors, document.errors unless document.valid?

      uploader = AncillaryFormAttachmentUploader.new(@current_user.uuid)
      uploader.store!(document.file_obj)

      #return guid for the upload
    end

    private

    def service
      EVSS::DisabilityCompensationForm::Service.new(@current_user)
    end
  end
end
