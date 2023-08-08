# frozen_string_literal: true

module DebtsApi
  class V0::Form5655Submission < ApplicationRecord
    self.table_name = 'form5655_submissions'
    validates :user_uuid, presence: true
    belongs_to :user_account, dependent: nil, optional: true
    has_kms_key
    has_encrypted :form_json, :metadata, key: :kms_key, **lockbox_options

    def form
      @form_hash ||= JSON.parse(form_json)
    end

    def submit_to_vba
      DebtsApi::V0::Form5655::VBASubmissionJob.perform_async(id, user_uuid)
    end

    def submit_to_vha
      DebtsApi::V0::Form5655::VHASubmissionJob.perform_async(id, user_uuid)
    end
  end
end
