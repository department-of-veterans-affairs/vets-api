# frozen_string_literal: true

class Post911NotFoundError < ActiveRecord::Base
  attr_encrypted :user_json, key: Settings.db_encryption_key

  scope :last_week, lambda { where("created_at >= :date", :date => 1.week.ago) }

  validates :user_uuid, presence: true, uniqueness: true
  validates :encrypted_user_json, :encrypted_user_json_iv, :request_timestamp, presence: true
end
