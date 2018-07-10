# frozen_string_literal: true

require 'emis/veteran_status_service'

module EMISRedis
  class VeteranStatus < Model
    CLASS_NAME = 'VeteranStatusService'

    def veteran?
      title38_status == 'V1'
    end

    def title38_status
      validated_response&.title38_status_code
    end

    # Returns boolean for user having/not having pre-911 combat deployment.
    #
    # @return [Boolean] If 'Y' or 'N' is returned from eMIS, returns associated boolean
    # @return [NilClass] If anything other than 'Y' or 'N' is returned from eMIS, returns nil
    #
    def pre_911_combat_deployment?
      coerce(validated_response&.pre911_deployment_indicator)
    end

    # Returns boolean for user having/not having ppost-911 combat deployment.
    #
    # @return [Boolean] If 'Y' or 'N' is returned from eMIS, returns associated boolean
    # @return [NilClass] If anything other than 'Y' or 'N' is returned from eMIS, returns nil
    #
    def post_911_combat_deployment?
      coerce(validated_response&.post911_deployment_indicator)
    end

    class NotAuthorized < StandardError
    end

    class RecordNotFound < StandardError
    end

    private

    def validated_response
      raise VeteranStatus::NotAuthorized unless @user.loa3?
      response = emis_response('get_veteran_status')

      raise VeteranStatus::RecordNotFound if response.empty?
      response.items.first
    end

    def coerce(y_or_n)
      value = y_or_n&.upcase

      return value if value.nil?

      case value
      when 'Y'
        true
      when 'N'
        false
      else
        nil
      end
    end
  end
end
