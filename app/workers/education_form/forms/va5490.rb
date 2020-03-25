# frozen_string_literal: true

module EducationForm::Forms
  class VA5490 < Base
    # rubocop:disable Layout/LineLength
    PREVIOUS_BENEFITS = {
      'disability' => 'DISABILITY COMPENSATION OR PENSION',
      'dic' => "DEPENDENTS' INDEMNITY COMPENSATION",
      'chapter31' => 'VOCATIONAL REHABILITATION BENEFITS (Chapter 31)',
      'chapter35' => "VETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: CHAPTER 35 - SURVIVORS' AND DEPENDENTS' EDUCATIONAL ASSISTANCE PROGRAM (DEA)",
      'chapter33' => "VETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: CHAPTER 33 - POST-9/11 GI BILL MARINE GUNNERY SERGEANT DAVID FRY SCHOLARSHIP",
      'transferOfEntitlement' => "VETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: TRANSFERRED ENTITLEMENT"
    }.freeze
    # rubocop:enable Layout/LineLength

    HIGH_SCHOOL_STATUS = {
      'graduated' => 'Graduated from high school',
      'discontinued' => 'Discontinued high school',
      'graduationExpected' => 'Expect to graduate from high school',
      'ged' => 'Awarded GED',
      'neverAttended' => 'Never attended high school'
    }.freeze

    def applicant_name
      @applicant.relativeFullName
    end

    def applicant_ssn
      @applicant.relativeSocialSecurityNumber
    end

    def school
      @applicant.educationProgram
    end

    def high_school_status
      status = @applicant.highSchool&.status
      return if status.nil?

      HIGH_SCHOOL_STATUS[status]
    end

    def previously_applied_for_benefits?
      previous_benefits.present?
    end

    def previous_benefits
      previous_benefits = @form.previousBenefits
      return if previous_benefits.blank?

      previous_benefits_arr = previous_benefits.to_h.map do |key, value|
        PREVIOUS_BENEFITS[key.to_s] if value == true
      end.compact

      if previous_benefits.ownServiceBenefits.present?
        own_service_benefits_txt = 'VETERANS EDUCATION ASSISTANCE BASED ON YOUR OWN SERVICE SPECIFY BENEFIT(S): '
        own_service_benefits_txt += previous_benefits.ownServiceBenefits

        previous_benefits_arr << own_service_benefits_txt
      end

      if previous_benefits.other.present?
        previous_benefits_arr << "OTHER; Specify benefit(s): #{previous_benefits.other}"
      end

      previous_benefits_arr.join("\n")
    end
  end
end
