# frozen_string_literal: true

module RapidReadyForDecision
  class HypertensionSpecialIssueManager
    attr_accessor :submission

    def initialize(submission)
      @submission = submission
    end

    def add_special_issue
      submission_data = JSON.parse(submission.form_json)
      disabilities = submission_data.dig('form526', 'form526', 'disabilities')
      disabilities.each do |disability|
        add_rrd_code(disability) if hypertension_increase?(disability)
      end
      submission.update!(form_json: JSON.dump(submission_data))
      submission.invalidate_form_hash
      submission
    end

    private

    HYPERTENSION_DISABILITY = RapidReadyForDecision::Constants::DISABILITIES[:hypertension]
    RRD_CODE = 'RRD'

    def hypertension_increase?(disability)
      RapidReadyForDecision::ProcessorSelector.disability_increase?(disability, HYPERTENSION_DISABILITY)
    end

    # Must return an array containing special string codes for EVSS
    def add_rrd_code(disability)
      disability['specialIssues'] ||= []
      disability['specialIssues'].append(RRD_CODE) unless disability['specialIssues'].include?(RRD_CODE)
      disability
    end
  end
end
