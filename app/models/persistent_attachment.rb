# frozen_string_literal: true
require 'attr_encrypted'
class PersistentAttachment < ActiveRecord::Base
  attr_encrypted(:file_data, key: Settings.db_encryption_key)
  belongs_to :saved_claim
  delegate :original_filename, :size, to: :file

  after_initialize :generate_guid, unless: :guid

  def generate_guid
    self.guid = SecureRandom.uuid
  end

  def process
    args = as_json.reject { |k, _v| k.to_s == 'file_data' }.deep_symbolize_keys
    args[:code] = saved_claim.confirmation_number
    args[:append_to_stamp] = saved_claim.confirmation_number
    self.class::UPLOADER_CLASS.new(args).start!(file)
  end
end
