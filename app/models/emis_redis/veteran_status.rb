# frozen_string_literal: true
require 'emis/veteran_status_service'

module EMISRedis
  class VeteranStatus < Model
    CLASS_NAME = 'VeteranStatusService'

    def veteran?
      title38_status == 'V1'
    end

    def title38_status
      raise VeteranStatus::NotAuthorized unless @user.loa3?
      response = emis_response('get_veteran_status')
      raise VeteranStatus::RecordNotFound if response.empty?
      response.items.first&.title38_status_code
    end

    class NotAuthorized < StandardError
    end

    class RecordNotFound < StandardError
    end
  end
end
