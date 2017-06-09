# frozen_string_literal: true
require 'appeals_status/models/event'
require 'appeals_status/models/relationships'
require 'common/models/base'

module AppealsStatus
  module Models
    class Appeal < Common::Base
      include Virtus.model
      attribute :active, Boolean
      attribute :type, String
      attribute :prior_decision_date, Date
      attribute :requested_hearing_type, String
      attribute :events, Array[AppealsStatus::Models::Event]
      attribute :relationships, AppealsStatus::Models::Relationships
    end
  end
end
