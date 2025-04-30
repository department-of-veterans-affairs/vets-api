# frozen_string_literal: true

require 'common/models/form'
require 'common/exceptions'

module BB
  class CreateAALForm < Common::Form
    include SentryLogging

    attribute :user_profile_id, Integer
    attribute :activity_type, String
    attribute :action, String
    attribute :completion_time, Common::UTCTime
    attribute :performer_type, String
    attribute :detail_value, String
    attribute :status, Integer

    validates :completion_time, date: true
    validates :status, inclusion: { in: [0, 1] }
    validates :user_profile_id, :activity_type, :action, :performer_type, :status, presence: true

    def initialize(attributes = {})
      super(attributes)
      self.completion_time ||= Time.current.utc
    end

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      {
        user_profile_id:,
        activity_type:,
        action:,
        completion_time: completion_time.try(:httpdate),
        performer_type:,
        detail_value:,
        status:
      }
    end
  end
end
