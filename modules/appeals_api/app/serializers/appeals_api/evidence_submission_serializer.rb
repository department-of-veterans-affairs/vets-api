# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmissionSerializer
    include JSONAPI::Serializer

    MAX_DETAIL_DISPLAY_LENGTH = 100

    set_id(&:guid)
    set_key_transform(:camel_lower)
    set_type(:evidenceSubmission)

    attributes :status, :code, :detail, :location

    attribute :appealId, &:supportable_id

    attribute :appealType do |object|
      object.supportable_type.to_s.demodulize
    end

    attribute :createDate, &:created_at
    attribute :updateDate, &:updated_at

    attribute :detail do |object|
      if object.detail
        value = object.detail.to_s
        value = "#{value[0..MAX_DETAIL_DISPLAY_LENGTH - 1]}..." if value.length > MAX_DETAIL_DISPLAY_LENGTH
        value
      end
    end

    attribute :location do |object, params|
      object.upload_submission.get_location if params[:render_location]
    rescue => e
      raise Common::Exceptions::InternalServerError, e
    end
  end
end
