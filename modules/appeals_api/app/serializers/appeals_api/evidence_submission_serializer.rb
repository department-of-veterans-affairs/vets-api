# frozen_string_literal: true

module AppealsApi
  class EvidenceSubmissionSerializer < ActiveModel::Serializer
    MAX_DETAIL_DISPLAY_LENGTH = 100

    type 'evidence_submission'

    attributes :id, :status, :code, :detail, :appeal_type, :appeal_id, :location, :created_at, :updated_at

    delegate :status, to: :object
    delegate :code, to: :object

    def id
      object.guid
    end

    def detail
      return unless object.detail

      details = object.detail.to_s
      details = "#{details[0..MAX_DETAIL_DISPLAY_LENGTH - 1]}..." if details.length > MAX_DETAIL_DISPLAY_LENGTH
      details
    end

    def appeal_type
      object.supportable_type.to_s.demodulize
    end

    def appeal_id
      object.supportable_id
    end

    def location
      return nil unless @instance_options[:render_location]

      object.upload_submission.get_location
    rescue => e
      raise Common::Exceptions::InternalServerError, e
    end
  end
end
