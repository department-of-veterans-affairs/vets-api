# frozen_string_literal: true

module V0
  class IntentToFilesController < ApplicationController
    before_action { authorize :evss, :access? }
    before_action :validate_type_param, only: %i[active submit]

    # currently, only `compensation` is supported. This will be expanded to
    # include `pension` and `survivor` in the future.
    TYPES = %w[compensation].freeze

    def index
      response = service.get_intent_to_file
      render json: response,
             serializer: IntentToFileSerializer
    end

    def active
      response = service.get_active(params[:type])
      render json: response,
             serializer: IntentToFileSerializer
    end

    def submit
      response = service.create_intent_to_file(params[:type])
      render json: response,
             serializer: IntentToFileSerializer
    end

    private

    def validate_type_param
      raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
        TYPES.include?(params[:type])
    end

    def service
      EVSS::IntentToFile::Service.new(@current_user)
    end
  end
end
