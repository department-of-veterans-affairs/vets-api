# frozen_string_literal: true

require 'evss/intent_to_file/service'
require 'evss/intent_to_file/response_strategy'
require 'disability_compensation/factories/api_provider_factory'
require 'logging/third_party_transaction'

module V0
  class IntentToFilesController < ApplicationController
    extend Logging::ThirdPartyTransaction::MethodWrapper

    before_action { authorize :evss, :access_form526? }
    before_action :validate_type_param, only: %i[active submit]

    wrap_with_logging(
      :index,
      :submit,
      additional_class_logs: {
        action: 'load Intent To File for 526 form flow'
      },
      additional_instance_logs: {
        user_uuid: %i[current_user account_uuid]
      }
    )

    # currently, only `compensation` is supported. This will be expanded to
    # include `pension` and `survivor` in the future.
    TYPES = %w[compensation].freeze

    def index
      intent_to_file_provider = ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:intent_to_file],
        provider: nil,
        options: {},
        current_user: @current_user,
        feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE
      )
      type = params['itf_type'] || 'compensation'
      response = intent_to_file_provider.get_intent_to_file(type, nil, nil)
      render json: response,
             serializer: IntentToFileSerializer
    end

    def active
      response = strategy.cache_or_service(@current_user.uuid, params[:type]) { service.get_active(params[:type]) }
      render json: response,
             serializer: IntentToFileSerializer
    end

    def submit
      intent_to_file_provider = ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:intent_to_file],
        provider: nil,
        options: {},
        current_user: @current_user,
        feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE
      )
      type = params['itf_type'] || 'compensation'
      response = intent_to_file_provider.create_intent_to_file(type, nil, nil)
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
