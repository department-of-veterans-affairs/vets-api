# frozen_string_literal: true
require 'appeals_status/models/hearing'
require 'appeals_status/models/issue'
require 'common/models/base'

module AppealsStatus
  module Models
    class Appeal < Common::Base
      include Virtus.model
      attribute :id, String
      attribute :active, Boolean
      attribute :decision_url, String
      attribute :status_message, String
      attribute :issues, Array[AppealsStatus::Models::Issue]
      attribute :soc_released_on, Date
      attribute :soc_url, String
      attribute :hearing, AppealsStatus::Models::Hearing
    end
  end
end
