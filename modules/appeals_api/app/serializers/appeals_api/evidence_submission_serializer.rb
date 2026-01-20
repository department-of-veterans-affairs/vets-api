# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmissionSerializer
    include JSONAPI::Serializer

    MAX_DETAIL_DISPLAY_LENGTH = 100

    set_id(&:guid)
    set_key_transform(:camel_lower)
    set_type(:evidence_submission)

    attributes :status, :code, :detail, :location

    attribute :appeal_id, &:supportable_id

    attribute :final_status, if: proc { |_, _|
      # The final_status will be serialized only if the :decision_review_evidence_final_status_field flag is enabled
      Flipper.enabled?(:decision_review_evidence_final_status_field)
    } do |object, _|
      object.in_final_status?
    end

    attribute :appeal_type do |object|
      object.supportable_type.to_s.demodulize
    end

    attribute :create_date, &:created_at
    attribute :update_date, &:updated_at

    attribute :detail do |object|
      if object.detail
        value = object.detail.to_s
        value = "#{value[0..(MAX_DETAIL_DISPLAY_LENGTH - 1)]}..." if value.length > MAX_DETAIL_DISPLAY_LENGTH
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
