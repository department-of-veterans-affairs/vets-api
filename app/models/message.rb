# frozen_string_literal: true

require 'common/models/base'

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
#   @return [Common::UTCTime]
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
class Message < Common::Base
  per_page 10
  max_per_page 100

  MAX_TOTAL_FILE_SIZE_MB = 10.0
  MAX_SINGLE_FILE_SIZE_MB = 6.0

  include ActiveModel::Validations
  include RedisCaching

  redis_config REDIS_CONFIG[:secure_messaging_store]

  # Only validate presence of category, recipient_id if new message or new draft message
  validates :category, :recipient_id, presence: true, unless: proc { reply? }

  # Always require body to be present: new message, drafts, and replies
  validates :body, presence: true
  validates :uploads, length: { maximum: 4, message: 'has too many files (maximum is 4 files)' }

  # Only validate upload sizes if uploads are present.
  validate :each_upload_size_validation, if: proc { uploads.present? }
  validate :total_upload_size_validation, if: proc { uploads.present? }

  attribute :id, Integer
  attribute :category, String
  attribute :subject, String, filterable: %w[eq not_eq match], sortable: { order: 'ASC' }
  attribute :body, String
  attribute :attachment, Boolean
  attribute :sent_date, Common::UTCTime, filterable: %w[eq lteq gteq], sortable: { order: 'DESC', default: true }
  attribute :sender_id, Integer
  attribute :sender_name, String, filterable: %w[eq not_eq match], sortable: { order: 'ASC' }
  attribute :recipient_id, Integer
  attribute :recipient_name, String, filterable: %w[eq not_eq match], sortable: { order: 'ASC' }
  attribute :read_receipt, String
  attribute :triage_group_name, String
  attribute :proxy_sender_name, String
  attribute :attachments, Array[Attachment]
  attribute :has_attachments, Boolean
  attribute :attachment1_id, Integer
  attribute :attachment2_id, Integer
  attribute :attachment3_id, Integer
  attribute :attachment4_id, Integer
  attribute :suggested_name_display, String

  # This is only used for validating uploaded files, never rendered
  attribute :uploads, Array[ActionDispatch::Http::UploadedFile]

  alias attachment? attachment

  def initialize(attributes = {})
    # temporarily coerce attachments to Attachment class
    # this will be removed when Message is switched to Vets::Model
    attributes[:attachments] = attributes[:attachments].map { |a| Attachment.new(a) } if attributes[:attachments]

    super(attributes)
    self.subject = subject ? Nokogiri::HTML.parse(subject) : nil
    self.body = body ? Nokogiri::HTML.parse(body) : nil
  end

  ##
  # @note Default sort should be sent date in descending order
  #
  def <=>(other)
    -(sent_date <=> other.sent_date)
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

  def total_upload_size
    return 0 if uploads.blank?

    uploads.sum(&:size)
  end

  def total_upload_size_validation
    return unless total_upload_size > MAX_TOTAL_FILE_SIZE_MB.megabytes

    errors.add(:base, "Total size of uploads exceeds #{MAX_TOTAL_FILE_SIZE_MB} MB")
  end

  def each_upload_size_validation
    uploads.each do |upload|
      next if upload.size <= MAX_SINGLE_FILE_SIZE_MB.megabytes

      errors.add(:base, "The #{upload.original_filename} exceeds file size limit of #{MAX_SINGLE_FILE_SIZE_MB} MB")
    end
  end
end
