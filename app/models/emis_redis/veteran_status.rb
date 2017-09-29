# frozen_string_literal: true
require 'emis/veteran_status_service'

module EMISRedis
  class VeteranStatus < Model
    CLASS_NAME = 'VeteranStatusService'

    def veteran?
      raise VeteranStatus::Unauthorized unless @user.loa3?
      response = emis_response('get_veteran_status')
      raise VeteranStatus::RecordNotFound if response.empty?
      any_veteran_indicator?(response.items.first)
    end

    class NotAuthorized < StandardError
    end

    class RecordNotFound < StandardError
    end

    private

    def any_veteran_indicator?(item)
      item.post911_deployment_indicator == 'Y' ||
        item.post911_combat_indicator == 'Y' ||
        item.pre911_deployment_indicator == 'Y'
    end
  end
end
