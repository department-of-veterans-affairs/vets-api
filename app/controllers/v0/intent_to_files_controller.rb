# frozen_string_literal: true

module V0
  class IntentToFilesController < ApplicationController
    before_action { authorize :evss, :access? }

    def index
      render json: service.get_intent_to_file,
             serializer: IntentToFileSerializer
    end

    def active_compensation
      render json: service.get_active_compensation,
             serializer: IntentToFileSerializer
    end

    def submit_compensation
      render json: service.create_intent_to_file_compensation,
             serializer: IntentToFileSerializer
    end

    private

    def service
      EVSS::IntentToFile::Service.new(@current_user)
    end
  end
end
