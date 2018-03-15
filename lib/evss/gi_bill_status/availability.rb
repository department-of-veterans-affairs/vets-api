# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module GiBillStatus
    class Availability < EVSS::Response
      attribute :is_available, Boolean
    end
  end
end
