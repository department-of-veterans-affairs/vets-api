# frozen_string_literal: true

require 'vets/model'

##
# Models a secure message
#
# @!attribute id
#   @return [Integer]
# @!attribute category
#   @return [String]
# @!attribute subject
#   @return [String]
# @!attribute body
#   @return [String]
# @!attribute attachment
#   @return [Boolean]
# @!attribute sent_date
#   @return [Vets::Type::UTCTime]
# @!attribute sender_id
#   @return [Integer]
# @!attribute sender_name
#   @return [String]
# @!attribute recipient_id
#   @return [Integer]
# @!attribute recipient_name
#   @return [String]
# @!attribute read_receipt
#   @return [String]
# @!attribute triage_group_name
#   @return [String]
# @!attribute proxy_sender_name
#   @return [String]
# @!attribute attachments
#   @return [Array[Attachment]] an array of Attachments
#
class Message
  include Vets::Model
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  # Only validate presence of category, recipient_id if new message or new draft message
  validates :category, :recipient_id, presence: true, unless: proc { reply? }

  # Always require body to be present: new message, drafts, and replies
  validates :body, presence: true

  # Only validate upload sizes if uploads are present.
  validate :total_file_count_validation, if: proc { uploads.present? }
  validate :each_upload_size_validation, if: proc { uploads.present? }
  validate :total_upload_size_validation, if: proc { uploads.present? }

  attribute :id, Integer
  attribute :category, String
  attribute :subject, String, filterable: %w[eq not_eq match]
  attribute :body, String
  attribute :attachment, Bool, default: false
  attribute :sent_date, Vets::Type::UTCTime, filterable: %w[eq lteq gteq]
  attribute :sender_id, Integer
  attribute :sender_name, String, filterable: %w[eq not_eq match]
  attribute :recipient_id, Integer
  attribute :recipient_name, String, filterable: %w[eq not_eq match]
  attribute :read_receipt, String
  attribute :triage_group_name, String
  attribute :proxy_sender_name, String
  attribute :attachments, Attachment, array: true
  attribute :has_attachments, Bool, default: false
  attribute :attachment1_id, Integer
  attribute :attachment2_id, Integer
  attribute :attachment3_id, Integer
  attribute :attachment4_id, Integer
  attribute :suggested_name_display, String
  attribute :is_oh_message, Bool, default: false
  attribute :metadata, Hash, default: -> { {} }
  attribute :is_large_attachment_upload, Bool, default: false
  attribute :reply_disabled, Bool, default: false

  # This is only used for validating uploaded files, never rendered
  attribute :uploads, ActionDispatch::Http::UploadedFile, array: true

  ##
  # @note Default sort should be sent date in descending order
  #
  default_sort_by sent_date: :desc
  set_pagination per_page: 10, max_per_page: 100

  alias attachment? attachment

  def initialize(attributes = {})
    # super is calling Vets::Model#initialize
    super(attributes)
    # this is called because Vets::Type::Primitive String can't
    # coerce html or Nokogiri doc to plain text
    # refactoring: the subject & body should be manipulated before passed to Message
    @subject = subject ? Nokogiri::HTML.parse(subject).text : nil
    @body = body ? Nokogiri::HTML.parse(body).text : nil
  end

  ##
  # @note This returns self so that it can be chained: Message.new(params).as_reply
  #
  def as_reply
    @reply = true
    self
  end

  ##
  # @return [Boolean] is there a reply?
  #
  def reply?
    @reply || false
  end

  private

  def max_single_file_size_mb
    is_large_attachment_upload ? 25.0 : 6.0
  end

  def total_upload_size
    return 0 if uploads.blank?

    uploads.sum(&:size)
  end

  def max_total_file_count
    is_large_attachment_upload ? 10 : 4
  end

  def max_total_file_size
    is_large_attachment_upload ? 25.0 : 10.0
  end

  def total_upload_size_validation
    return unless total_upload_size > max_total_file_size.megabytes

    errors.add(:base, "Total size of uploads exceeds #{max_total_file_size} MB")
  end

  def each_upload_size_validation
    uploads.each do |upload|
      next if upload.size <= max_single_file_size_mb.megabytes

      errors.add(:base, "The #{upload.original_filename} exceeds file size limit of #{max_single_file_size_mb} MB")
    end
  end

  def total_file_count_validation
    return unless uploads.length > max_total_file_count

    errors.add(:base, "Total file count exceeds #{max_total_file_count} files")
  end
end
