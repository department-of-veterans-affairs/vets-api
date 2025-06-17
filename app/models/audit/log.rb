# frozen_string_literal: true

module Audit
  class Log < ApplicationRecord
    IDENTIFIER_TYPES = {
      icn: 'icn',
      logingov_uuid: 'logingov_uuid',
      idme_uuid: 'idme_uuid',
      mhv_id: 'mhv_id',
      dslogon_id: 'dslogon_id',
      system_hostname: 'system_hostname'
    }.freeze

    validates :subject_user_identifier, presence: true
    validates :acting_user_identifier, presence: true
    validates :event_id, presence: true
    validates :event_description, presence: true
    validates :event_status, presence: true
    validates :event_occurred_at, presence: true
    validates :message, presence: true

    enum :subject_user_identifier_type, IDENTIFIER_TYPES, prefix: true, validate: true
    enum :acting_user_identifier_type, IDENTIFIER_TYPES, prefix: true, validate: true
  end
end
