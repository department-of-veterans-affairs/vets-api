# frozen_string_literal: true
require 'appeals_status/models/appeal'

module AppealStatus
  module Models
    class Appeals
      include Virtus.model
      attribute :appeals, Array[AppealStatus::Models::Appeal]
    end
  end
end
