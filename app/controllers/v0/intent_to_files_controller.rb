# frozen_string_literal: true

require 'evss/intent_to_file/service'
require 'evss/intent_to_file/response_strategy'
require 'disability_compensation/factories/api_provider_factory'

module V0
  class IntentToFilesController < ApplicationController
    before_action { authorize :evss, :access_form526? }
    before_action :validate_type_param, only: %i[active submit]

    # currently, only `compensation` is supported. This will be expanded to
    # include `pension` and `survivor` in the future.
    TYPES = %w[compensation].freeze

    def index
      intent_to_file_service = ApiProviderFactory.intent_to_file_service_provider(@current_user)
      response = intent_to_file_service.get_intent_to_file
      render json: response,
             serializer: IntentToFileSerializer
    end

    def active
      response = strategy.cache_or_service(@current_user.uuid, params[:type]) { service.get_active(params[:type]) }
      render json: response,
             serializer: IntentToFileSerializer
    end

    def submit
      intent_to_file_service = ApiProviderFactory.intent_to_file_service_provider(@current_user)

      response = intent_to_file_service.create_intent_to_file(params[:type])
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

    def strategy
      EVSS::IntentToFile::ResponseStrategy.new
    end
  end
end
