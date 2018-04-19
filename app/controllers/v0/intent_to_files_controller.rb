# frozen_string_literal: true

module V0
  class IntentToFilesController < ApplicationController
    before_action { authorize :evss, :access? }

    def index
      response = service.get_intent_to_file
      render json: response,
             serializer: IntentToFileSerializer
    end

    def active_compensation
      response = service.get_active_compensation
      render json: response,
             serializer: IntentToFileSerializer
    end

    def submit_compensation
      response = service.create_intent_to_file_compensation
      render json: response,
             serializer: IntentToFileSerializer
    end

    private

    def service
      EVSS::IntentToFile::Service.new(@current_user)
    end
  end
end
