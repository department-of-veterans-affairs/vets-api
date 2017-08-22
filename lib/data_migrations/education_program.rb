module DataMigrations
  module EducationProgram
    module_function

    def migrate
      EducationBenefitsClaim.where(form_type: '1990').find_each do |education_benefits_claim|
        parsed_form = education_benefits_claim.parsed_form

        if parsed_form['educationProgram'].blank?
          parsed_form['educationProgram'] = parsed_form['school'] || {}
          parsed_form['educationProgram']['educationType'] = parsed_form['educationType']
        end

        parsed_form.delete('school')
        parsed_form.delete('educationType')
        education_benefits_claim.instance_variable_set(:@parsed_form, nil)

        education_benefits_claim.update_attributes!(form: parsed_form.to_json)
      end
    end
  end
end
