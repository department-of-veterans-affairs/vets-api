# frozen_string_literal: true
module EducationForm::Forms
  class VA1995 < Base
    TYPE = '22-1995'

    FORM_TYPES = {
      'chapter30': 'CH30',
      'chapter32': 'CH32',
      'chapter33': 'CH33',
      'chapter1606': 'CH1606',
      'chapter1607': 'CH1607',
      'transferOfEntitlement': 'TransferOfEntitlement'
    }.freeze

    def school
      @applicant.newSchool
    end

    def form_type(applicant)
      FORM_TYPES[applicant.benefit&.to_sym]
    end

    def direct_deposit_type(type)
      case type&.upcase
      when 'STARTUPDATE' then 'Start or Update'
      when 'STOP' then 'Stop'
      when 'NOCHANGE' then 'Do Not Change'
      end
    end
  end
end
