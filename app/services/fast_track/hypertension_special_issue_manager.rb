# frozen_string_literal: true

module FastTrack
  class HypertensionSpecialIssueManager
    attr_accessor :submission

    def initialize(submission)
      @submission = submission
    end

    def add_special_issue
      data = JSON.parse(submission.form_json, symbolize_names: true)
      disabilities = data[:form526][:form526][:disabilities]
      data[:form526][:form526][:disabilities] = add_rrd_to_disabilities(disabilities)
      submission.update!(form_json: JSON.dump(data))
    end

    def add_rrd_to_disabilities(disabilities)
      disabilities.each do |da|
        add_rrd(da) if da[:diagnosticCode] == 7101 && da[:disabilityActionType].downcase == 'increase'
      end
      disabilities
    end

    def add_rrd(disability)
      rrd_hash = { code: 'RRD', name: 'Rapid Ready for Decision' }
      if disability[:specialIssues].blank?
        disability[:specialIssues] = [rrd_hash]
      elsif !disability[:specialIssues].include? rrd_hash
        disability[:specialIssues].append(rrd_hash)
      end
      disability
    end
  end
end
