# frozen_string_literal: true

module RapidReadyForDecision
  class HypertensionSpecialIssueManager
    attr_accessor :submission

    def initialize(submission)
      @submission = submission
    end

    def add_special_issue
      disabilities.each do |disability|
        add_rrd_code(disability) if hypertension_increase?(disability)
      end
      submission.update!(form_json: JSON.dump(submission_data))
    end

    private

    def submission_data
      @submission_data ||= JSON.parse(submission.form_json, symbolize_names: true)
    end

    def disabilities
      @disabilities ||= submission_data[:form526][:form526][:disabilities]
    end

    def hypertension_increase?(disability)
      disability[:diagnosticCode] == 7101 && disability[:disabilityActionType].downcase == 'increase'
    end

    RRD_CODE = 'RRD'

    # Must return an array containing special string codes for EVSS
    def add_rrd_code(disability)
      disability[:specialIssues] ||= []
      disability[:specialIssues].append(RRD_CODE) unless disability[:specialIssues].include?(RRD_CODE)
      disability
    end
  end
end
