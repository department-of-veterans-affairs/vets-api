# frozen_string_literal: true
require 'appeals_status/models/hearing'
require 'appeals_status/models/issue'

module AppealStatus
  module Models
    class Appeal
      include Virtus.model
      attribute :id, String
      attribute :active, Boolean
      attribute :decision_url, String
      attribute :status_message, String
      attribute :issues, Array[AppealStatus::Models::Issue]
      attribute :soc_released_on, Date
      attribute :soc_url, String
      attribute :hearing, AppealStatus::Models::Hearing
    end
  end
end
