# frozen_string_literal: true

module EducationForm::Forms
  class VA1990 < Base
    ### ERB HELPERS

    CH33_TYPES = {
      'chapter1607' => 'CH33_1607', 'chapter1606' => 'CH33_1606', 'chapter30' => 'CH33_30'
    }.freeze

    # If multiple benefit types are selected, we've been told to just include whichever
    # one is 'first' in the header.
    def benefit_type(application)
      return 'CH1606' if application.chapter1606
      return 'CH1607' if application.chapter1607
      return 'CH33' if application.chapter33
      return 'CH30' if application.chapter30

      'CH32' if application.chapter32
    end

    def non_va_assistance
      @applicant.currentlyActiveDuty&.nonVaAssistance
    end

    def school
      @applicant.educationProgram
    end

    def education_type
      @applicant.educationProgram&.educationType
    end

    # Some descriptive text that's included near the top of the 22-1990 form. Because they can make
    # multiple selections, we have to add all the selected ones.
    def disclosures(application)
      disclosure_texts = []
      disclosure_texts << disclosure_for('CH30') if application.chapter30
      disclosure_texts << disclosure_for('CH1606') if application.chapter1606
      disclosure_texts << disclosure_for('CH32') if application.chapter32
      if application.chapter33
        ch33_type = CH33_TYPES.fetch(application.benefitsRelinquished, 'CH33')
        disclosure_texts << disclosure_for(ch33_type)
      end
      disclosure_texts.join("\n#{'*' * 78}\n\n")
    end

    def rotc_scholarship_amounts(scholarships)
      # there are 5 years, all of which can be blank.
      # Wrap the array to a size of 5 to meet this requirement
      wrapped_list = Array(scholarships)
      Array.new(5) do |idx|
        "            Year #{idx + 1}:          Amount: #{wrapped_list[idx]&.amount}\n"
      end.join("\n")
    end
  end
end
