# frozen_string_literal: true
require 'emis/veteran_status_service'

class VeteranStatus < EMISModel
  CLASS_NAME = 'VeteranStatusService'
  redis_config_key :veteran_status_response

  def veteran?
    raise VeteranStatus::Unauthorized unless @user.loa3?
    any_veteran_indicator?(emis_response('get_veteran_status').items.first)
  end

  private

  def any_veteran_indicator?(item)
    item.post911_deployment_indicator == 'Y' ||
      item.post911_combat_indicator == 'Y' ||
      item.pre911_deployment_indicator == 'Y'
  end
end
