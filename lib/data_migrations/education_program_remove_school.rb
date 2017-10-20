module DataMigrations
  module EducationProgramRemoveSchool
    module_function

    def run
      SavedClaim::EducationBenefits::VA1990.find_each do |saved_claim|
        parsed_form = saved_claim.parsed_form

        school = parsed_form['school']
        education_program = parsed_form['educationProgram']
        education_type = parsed_form['educationType']

        next if school.blank? && education_type.blank?

        if school.present?
          %w(name address).each do |attr|
            raise unless school[attr] == education_program.try(:[], attr)
          end

          parsed_form.delete('school')
        end

        if education_type.present?
          raise unless education_type == education_program.try(:[], 'educationType')
          parsed_form.delete('educationType')
        end

        saved_claim.instance_variable_set(:@parsed_form, nil)

        saved_claim.update_attributes!(form: parsed_form.to_json)
      end
    end
  end
end
