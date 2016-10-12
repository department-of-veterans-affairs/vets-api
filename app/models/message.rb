# frozen_string_literal: true
require 'common/models/base'

# Message model
class Message < Common::Base
  MEGABYTE = 1024.0 * 1024.0
  MAX_TOTAL_FILE_SIZE = 6.0
  MAX_SINGLE_FILE_SIZE = 3.0

  include ActiveModel::Validations

  validates :body, :category, :recipient_id, presence: true
  validate :each_upload_size_validation
  validate :total_upload_size_validation

  attribute :id, Integer
  attribute :category, String
  attribute :subject, String
  attribute :body, String
  attribute :attachment, Boolean
  attribute :sent_date, Common::UTCTime
  attribute :sender_id, Integer
  attribute :sender_name, String
  attribute :recipient_id, Integer
  attribute :recipient_name, String
  attribute :read_receipt, String
  attribute :attachments, Array[Attachment]

  # This is only used for validating uploaded files, never rendered
  attribute :uploads, Array[ActionDispatch::Http::UploadedFile]

  alias attachment? attachment

  def <=>(other)
    id <=> other.id
  end

  private

  def total_upload_size
    return 0 unless uploads.present?
    uploads.sum(&:size)
  end

  def total_upload_size_validation
    return unless (total_upload_size.to_f / MEGABYTE) > 6.0
    errors.add(:base, "Total size of uploads exceeds #{MAX_TOTAL_FILE_SIZE} MB")
  end

  def each_upload_size_validation
    return unless uploads.present?
    uploads.each do |upload|
      next if (upload.size.to_f / MEGABYTE) <= MAX_SINGLE_FILE_SIZE
      errors.add(:base, "#{upload.original_filename} exceeds file size limit of #{MAX_SINGLE_FILE_SIZE} MB")
    end
  end
end
