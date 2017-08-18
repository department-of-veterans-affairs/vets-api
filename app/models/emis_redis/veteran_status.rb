# frozen_string_literal: true
require 'emis/veteran_status_service'

module EMISRedis
  class VeteranStatus < Model
    CLASS_NAME = 'VeteranStatusService'

    def veteran?
      raise VeteranStatus::NotAuthorized unless @user.loa3?
      any_veteran_indicator?(emis_response('get_veteran_status').items.first)
    end

    class NotAuthorized < StandardError
    end

    private

    def any_veteran_indicator?(item)
      item.post911_deployment_indicator == 'Y' ||
        item.post911_combat_indicator == 'Y' ||
        item.pre911_deployment_indicator == 'Y'
    end
  end
end
