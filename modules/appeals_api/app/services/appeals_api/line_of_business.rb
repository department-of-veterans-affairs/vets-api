# frozen_string_literal: true

module AppealsApi
  class LineOfBusiness
    def initialize(upload_submission)
      @upload_submission = upload_submission
    end

    def value
      appeal.lob
    end

    private

    attr_reader :upload_submission

    def evidence_submission
      @evidence_submission ||= AppealsApi::EvidenceSubmission.find_by(
        upload_submission_id: upload_submission.id
      )
    end

    def appeal
      @appeal ||= evidence_submission.supportable
    end
  end
end
