# frozen_string_literal: true

require 'disability_compensation/factories/api_provider_factory'
require 'logging/third_party_transaction'
require 'lighthouse/benefits_claims/intent_to_file/api_response'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

module V0
  class IntentToFilesController < ApplicationController
    extend Logging::ThirdPartyTransaction::MethodWrapper
    service_tag 'intent-to-file'

    class MissingICNError < StandardError; end
    class MissingParticipantIDError < StandardError; end
    class InvalidITFTypeError < StandardError; end

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

    ITF_FORM_IDS = {
      'compensation' => '21-526EZ',
      'pension' => '21P-527EZ',
      'survivor' => '21P-534EZ'
    }.freeze

    def index
      type = params['itf_type'] || 'compensation'

      if %w[pension survivor].include? type
        form_id = ITF_FORM_IDS[type]
        validate_data(@current_user, 'get', form_id, type)

        monitor.track_show_itf(form_id, type, @current_user.uuid)
        itf = BenefitsClaims::Service.new(@current_user.icn).get_intent_to_file(type, nil, nil)
        response = BenefitsClaims::IntentToFile::ApiResponse::GET.new(itf['data'])

        return render json: IntentToFileSerializer.new(response)
      end

      if Flipper.enabled?(:disability_compensation_production_tester, @current_user)
        Rails.logger.info("ITF GET call skipped for user #{@current_user.uuid}")
        response = set_success_response
      else
        response = intent_to_file_provider.get_intent_to_file(type, nil, nil)
      end
      render json: IntentToFileSerializer.new(response)
    rescue => e
      Rails.logger.error("Error occurred while processing ITF GET request: #{e.message}")
      monitor.track_itf_controller_error('get', form_id, type, e.message)
      raise e
    end

    def submit
      type = params['itf_type'] || 'compensation'

      if %w[pension survivor].include? type
        form_id = ITF_FORM_IDS[type]
        validate_data(@current_user, 'post', form_id, type)

        monitor.track_submit_itf(form_id, type, @current_user.uuid)
        itf = BenefitsClaims::Service.new(@current_user.icn).create_intent_to_file(type, @current_user.ssn, nil)
        response = BenefitsClaims::IntentToFile::ApiResponse::POST.new(itf['data'])

        return render json: IntentToFileSerializer.new(response)
      end

      if Flipper.enabled?(:disability_compensation_production_tester, @current_user)
        Rails.logger.info("ITF submit call skipped for user #{@current_user.uuid}")
        response = set_success_response
      else
        response = intent_to_file_provider.create_intent_to_file(type, nil, nil)
      end
      render json: IntentToFileSerializer.new(response)
    rescue => e
      Rails.logger.error("Error occurred while processing ITF submit request: #{e.message}")
      monitor.track_itf_controller_error('post', form_id, type, e.message)
      raise e
    end

    private

    def intent_to_file_provider
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:intent_to_file],
        provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
        options: {},
        current_user: @current_user,
        feature_toggle: nil
      )
    end

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
      raise Common::Exceptions::InvalidFieldValue.new('itf_type', params[:itf_type]) unless
        TYPES.include?(params[:itf_type])
    end

    # This is temporary. Testing logged data to ensure this is being hit properly
    # rubocop:disable Metrics/MethodLength
    def validate_data(user, method, form_id, itf_type)
      if Flipper.enabled?(:pension_itf_validate_data_logger, user)
        context = {
          user_icn_present: user.icn.present?,
          user_participant_id_present: user.participant_id.present?,
          itf_type:,
          user_uuid: user.uuid
        }
        Rails.logger.info('IntentToFilesController ITF Validate Data', context)
      end

      user_uuid = user.uuid

      if user.icn.blank?
        error_message = 'ITF request failed. No veteran ICN provided'
        monitor.track_missing_user_icn_itf_controller(method, form_id, itf_type, user_uuid, error_message)

        raise MissingICNError, error_message
      end

      if user.participant_id.blank?
        info_message = 'User missing participant ID which will be created by Lighthouse within MPI'
        monitor.track_missing_user_pid_itf_controller(method, form_id, itf_type, user_uuid, info_message)
      end

      if form_id.blank?
        error_message = 'ITF request failed. ITF type not supported'
        monitor.track_invalid_itf_type_itf_controller(method, form_id, itf_type, user_uuid, error_message)

        raise InvalidITFTypeError, error_message
      end
    end
    # rubocop:enable Metrics/MethodLength

    def monitor
      @monitor ||= BenefitsClaims::IntentToFile::Monitor.new
    end
  end
end
