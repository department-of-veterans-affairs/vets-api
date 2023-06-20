# frozen_string_literal: true

require 'user_profile_attribute_service'

class Form5655Submission < ApplicationRecord
  validates :user_uuid, presence: true
  belongs_to :user_account, dependent: nil, optional: true
  has_kms_key
  has_encrypted :form_json, :metadata, key: :kms_key, **lockbox_options

  def form
    @form_hash ||= JSON.parse(form_json)
  end

  def user_cache_id
    UserProfileAttributeService.new(@user).cache_profile_attributes
  end

  def submit_to_vba
    Form5655::VBASubmissionJob.perform_async(id, user_cache_id)
  end

  def submit_to_vha
    Form5655::VHASubmissionJob.perform_async(id, user_cache_id)
  end
end
