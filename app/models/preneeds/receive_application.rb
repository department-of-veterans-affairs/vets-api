# frozen_string_literal: true
require 'common/models/base'

# DischargeType model
module Preneeds
  class ReceiveApplication < Common::Base
    attribute :tracking_number, String
    attribute :return_code, Integer
    attribute :application_uuid, String
    attribute :return_description, String
    attribute :submitted_at, Time, default: lambda { |_, __| Time.zone.now }

    def receive_application_id
      tracking_number
    end
  end
end
