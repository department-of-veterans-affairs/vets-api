# frozen_string_literal: true

require 'user_profile_attribute_service'

class Form5655Submission < ApplicationRecord
  class StaleUserError < StandardError; end

  validates :user_uuid, presence: true
  belongs_to :user_account, dependent: nil, optional: true
  has_kms_key
  has_encrypted :form_json, :metadata, key: :kms_key, **lockbox_options

  scope :streamlined, -> { where("(public_metadata -> 'streamlined' ->> 'value')::boolean") }
  scope :not_streamlined, -> { where.not("(public_metadata -> 'streamlined' ->> 'value')::boolean") }
  scope :streamlined_unclear, -> { where("(public_metadata -> 'streamlined') IS NULL") }
  scope :streamlined_nil, lambda {
                            where("(public_metadata -> 'streamlined') IS NOT NULL and " \
                                  "(public_metadata -> 'streamlined' ->> 'value') IS NULL")
                          }

  def public_metadata
    super || {}
  end

  def form
    @form_hash ||= JSON.parse(form_json)
  end

  def user_cache_id
    user = User.find(user_uuid)
    raise StaleUserError, user_uuid unless user

    UserProfileAttributeService.new(user).cache_profile_attributes
  end

  def submit_to_vba
    Form5655::VBASubmissionJob.perform_async(id, user_cache_id)
  end

  def submit_to_vha
    Form5655::VHASubmissionJob.perform_async(id, user_cache_id)
  end

  def streamlined?
    public_metadata.dig('streamlined', 'value') == true
  end
end
