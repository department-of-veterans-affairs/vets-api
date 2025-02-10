# frozen_string_literal: true

require 'disability_compensation/factories/api_provider_factory'
require 'logging/third_party_transaction'

module V0
  class IntentToFilesController < ApplicationController
    extend Logging::ThirdPartyTransaction::MethodWrapper
    service_tag 'intent-to-file'

    before_action :authorize_service
    before_action :validate_type_param, only: %i[submit]

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
        provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
        options: {},
        current_user: @current_user,
        feature_toggle: nil
      )
      type = params['itf_type'] || 'compensation'
      if Flipper.enabled?(:disability_compensation_production_tester, @current_user)
        Rails.logger.info("ITF GET call skipped for user #{@current_user.uuid}")
        response = set_success_response
      else
        response = intent_to_file_provider.get_intent_to_file(type, nil, nil)
      end
      render json: IntentToFileSerializer.new(response)
    end

    def submit
      intent_to_file_provider = ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:intent_to_file],
        provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
        options: {},
        current_user: @current_user,
        feature_toggle: nil
      )
      type = params['itf_type'] || 'compensation'
      if Flipper.enabled?(:disability_compensation_production_tester, @current_user)
        Rails.logger.info("ITF submit call skipped for user #{@current_user.uuid}")
        response = set_success_response
      else
        response = intent_to_file_provider.create_intent_to_file(type, nil, nil)
      end
      render json: IntentToFileSerializer.new(response)
    end

    private

    def set_success_response
      DisabilityCompensation::ApiProvider::IntentToFilesResponse.new(
        intent_to_file: [
          DisabilityCompensation::ApiProvider::IntentToFile.new(
            id: '0',
            creation_date: DateTime.now,
            expiration_date: DateTime.now + 1.year,
            source: '',
            participant_id: 0,
            status: 'active',
            type: 'compensation'
          )
        ]
      )
    end

    def authorize_service
      authorize :lighthouse, :itf_access?
    end

    def validate_type_param
      raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
        TYPES.include?(params[:type])
    end
  end
end
