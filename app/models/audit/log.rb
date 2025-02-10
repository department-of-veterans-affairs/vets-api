# frozen_string_literal: true

module Audit
  class Log < ApplicationRecord
    validates :subject_user_identifier, :subject_user_identifier_type, :acting_user_identifier,
              :acting_user_identifier_type, :event_description, :event_status, :event_occurred_at,
              :message, presence: true
  end
end
