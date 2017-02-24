# frozen_string_literal: true
module EducationForm::Forms
  class VA1995 < Base
    TYPE = '22-1995'

    def school
      @applicant.newSchool
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def form_type(applicant)
      case applicant.benefit
      when 'chapter30' then 'CH30'
      when 'chapter32' then 'CH32'
      when 'chapter33' then 'CH33'
      when 'chapter1606' then 'CH1606'
      when 'chapter1607' then 'CH1607'
      when 'transferOfEntitlement' then 'TOE'
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def direct_deposit_type(type)
      case type&.upcase
      when 'STARTUPDATE' then 'Start or Update'
      when 'STOP' then 'Stop'
      when 'NOCHANGE' then 'Do Not Change'
      end
    end
  end
end
