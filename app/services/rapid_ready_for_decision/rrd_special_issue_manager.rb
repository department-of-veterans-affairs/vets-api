# frozen_string_literal: true

module RapidReadyForDecision
  class RrdSpecialIssueManager
    attr_accessor :submission

    def initialize(submission)
      @submission = submission
    end

    def add_special_issue
      submission_data = JSON.parse(submission.form_json)
      disabilities = submission_data.dig('form526', 'form526', 'disabilities')
      disabilities.each do |disability|
        add_rrd_code(disability) if included_disability_increase?(disability)
      end
      submission.update!(form_json: JSON.dump(submission_data))
      submission.invalidate_form_hash
      submission
    end

    private

    RRD_DIAGNOSTIC_CODES = RapidReadyForDecision::Constants::DISABILITIES_BY_CODE.keys
    RRD_CODE = 'RRD'

    # Checks if the disability is supported by RRD and that it is a request for increase
    def included_disability_increase?(disability)
      RRD_DIAGNOSTIC_CODES.include?(disability['diagnosticCode']) &&
        disability['disabilityActionType']&.upcase == 'INCREASE'
    end

    # Must return an array containing special string codes for EVSS
    def add_rrd_code(disability)
      disability['specialIssues'] ||= []
      disability['specialIssues'].append(RRD_CODE) unless disability['specialIssues'].include?(RRD_CODE)
      disability
    end
  end
end
