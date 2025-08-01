# frozen_string_literal: true

module DebtsApi
  class V0::DigitalDispute < Common::Base
    include ActiveModel::Validations

    STATS_KEY = 'api.digital_dispute_submission'
    ACCEPTED_CONTENT_TYPE = 'application/pdf'
    MAX_FILE_SIZE = 1.megabyte

    attribute :user, Object
    attribute :attachments, Array

    validate :validate_files

    def initialize(user, files)
      super()
      @raw_files = Array(files)
      self.user = user
    end

    def submit_to_dmc
      return unless valid?

      self.attachments = prepare_attachments(@raw_files)
      DebtsApi::V0::DigitalDisputeJob.perform_async(user_payload, attachments)
    end

    def validate_files
      if @raw_files.blank?
        errors.add(:attachments, 'At least one file is required')
        return
      end

      @raw_files.each_with_index do |file, index|
        file_index = index + 1

        if file.content_type != ACCEPTED_CONTENT_TYPE
          errors.add(:attachments, "File #{file_index} must be a PDF")
        end

        if file.size > MAX_FILE_SIZE
          errors.add(:attachments, "File #{file_index} is too large (maximum is 1MB)")
        end
      end
    end

    def sanitize_filename(filename)
      name = File.basename(filename)
      name = name.tr(':', '_')
      name.gsub(/[.](?=.*[.])/, '')
    end

    private

    def prepare_attachments(files)
      files.map do |file|
        {
          'fileName' => sanitize_filename(file.original_filename),
          'fileContents' => Base64.strict_encode64(file.read)
        }
      end
    end

    def user_payload
      {
        uuid: user.uuid,
        ssn: user.ssn,
        participant_id: user.participant_id
      }.stringify_keys
    end
  end
end
