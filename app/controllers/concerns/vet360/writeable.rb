# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'va_profile/contact_information/v2/service'

module Vet360
  module Writeable
    extend ActiveSupport::Concern

    PROFILE_AUDIT_LOG_TYPES = { email: :update_email_address,
                                address: :update_mailing_address,
                                telephone: :update_phone_number }.with_indifferent_access.freeze

    # For the passed VAProfile model type and params, it:
    #   - builds and validates a VAProfile models
    #   - POSTs/PUTs the model data to VAProfile
    #   - creates a new AsyncTransaction db record, based on the type
    #   - renders the transaction through the base serializer
    #
    # @param type [String] the VAProfile::Models type (i.e. 'Email', 'Address', etc.)
    # @param params [ActionController::Parameters ] The strong params from the controller
    # @param http_verb [String] The type of write request being made to VAProfile ('post' or 'put')
    # @return [Response] Normal controller `render json:` response with a response.body, .status, etc.
    #
    def write_to_vet360_and_render_transaction!(type, params, http_verb: 'post')
      record = build_record(type, params)
      validate!(record)
      response = write_valid_record!(http_verb, type, record)
      create_user_audit_log(type) if PROFILE_AUDIT_LOG_TYPES[type].present?
      render_new_transaction!(type, response)
    end

    def invalidate_cache
      VAProfileRedis::V2::Cache.invalidate(@current_user)
    end

    private

    def build_record(type, params)
      # This needs to be refactored after V2 upgrade is complete
      if type == 'address'
        model = 'VAProfile::Models::Address'
        Rails.logger.info("Override Key Present? #{params[:override_validation_key].present?},
                           Validation present? #{params[:validation_key].present?}")
        # Validation Key was deprecated with ContactInformationV2
        params[:override_validation_key] ||= params[:validation_key]
        params[:validation_key] ||= params[:override_validation_key]

        # Ensures the address_pou is valid
        if params[:address_pou] == 'RESIDENCE/CHOICE'
          params[:address_pou] = 'RESIDENCE'
          Rails.logger.info('RESIDENCE/CHOICE POU conversion detected')
        end
      else
        model = "VAProfile::Models::#{type.capitalize}"
      end
      model.constantize
           .new(params)
           .set_defaults(@current_user)
    end

    def create_user_audit_log(type)
      UserAudit.logger.success(event: PROFILE_AUDIT_LOG_TYPES[type],
                               user_verification: @current_user.user_verification)
    end

    def validate!(record)
      return if record.valid?

      PersonalInformationLog.create!(
        data: record.to_h,
        error_class: "#{record.class} ValidationError"
      )
      raise Common::Exceptions::ValidationErrors, record
    end

    def service
      VAProfile::ContactInformation::V2::Service.new @current_user
    end

    def write_valid_record!(http_verb, type, record)
      Rails.logger.info('Contact Info', http_verb, type)
      # This will be removed after the upgrade. Permission was removed in the upgraded service.
      # Permissions are not used in ContactInformationV1 either.
      service.send("#{http_verb}_#{type.downcase}", record)
    end

    def render_new_transaction!(type, response)
      transaction = "AsyncTransaction::VAProfile::#{type.capitalize}Transaction".constantize.start(
        @current_user, response
      )
      render json: AsyncTransaction::BaseSerializer.new(transaction).serializable_hash
    end

    def add_effective_end_date(params)
      params[:effective_end_date] = Time.now.utc.iso8601
      params
    end
  end
end
