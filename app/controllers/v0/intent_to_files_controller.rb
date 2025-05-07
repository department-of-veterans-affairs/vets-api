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

    TYPES = %w[compensation pension survivor].freeze

    def index
      intent_to_file_provider = ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:intent_to_file],
        provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
        options: {},
        current_user: @current_user,
        feature_toggle: nil
      )
      type = params['itf_type'] || 'compensation'

      if %w[pension survivor].include? type
        service = BenefitsClaims::Service.new(@current_user.icn)
        data = service.get_intent_to_file(type, nil, nil)['data']
        return render json: IntentToFileSerializer.new(transform_response(data:))
      end

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

      if %w[pension survivor].include? type
        service = BenefitsClaims::Service.new(@current_user.icn)
        data = service.create_intent_to_file(type, @current_user.ssn, nil)['data']
        return render json: IntentToFileSerializer.new(transform_response(data:, create: true))
      end

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

    def transform_response(data:, create: false)
      intent_to_file = DisabilityCompensation::ApiProvider::IntentToFile.new(
        id: data['id'],
        creation_date: data['attributes']['creationDate'],
        expiration_date: data['attributes']['expirationDate'],
        source: '',
        participant_id: 0,
        status: data['attributes']['status'],
        type: data['attributes']['type']
      )
      intent_to_file = [intent_to_file] if create

      DisabilityCompensation::ApiProvider::IntentToFilesResponse.new(intent_to_file:)
    end

    def authorize_service
      authorize :lighthouse, :itf_access?
    end

    def validate_type_param
      raise Common::Exceptions::InvalidFieldValue.new('itf_type', params[:itf_type]) unless
        TYPES.include?(params[:itf_type])
    end
  end
end
