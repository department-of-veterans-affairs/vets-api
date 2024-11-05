# frozen_string_literal: true

require 'bgs_service/redis/find_poas_service'

module ClaimsApi
  class FindPoasJob < ClaimsApi::ServiceBase
    def perform
      ClaimsApi::Logger.log('find_poas_job', detail: 'Find POAs Job started')

      response = ClaimsApi::FindPOAsService.new.response

      detail = response.is_a?(Array) && response.size.positive? ? 'Find POAs cached' : 'Find POAs failed'
      ClaimsApi::Logger.log('find_poas_job', detail:)

      ClaimsApi::Logger.log('find_poas_job', detail: 'Find POAs Job completed')
    end
  end
end
