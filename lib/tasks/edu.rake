# frozen_string_literal: true
namespace :edu do
  desc 'Given a confirmation number, print a spool file entry'
  task :print, [:id] => [:environment] do |_t, args|
    raise 'need to give an id. edu:print[{id}]' if args[:id].blank?
    id = args[:id].gsub(/\D/, '').to_i
    app = EducationBenefitsClaim.find(id)
    puts EducationForm::Forms::Base.build(app).text
  end

  desc 'Convert Education benefits claims to use educationProgram'
  task education_program: :environment do
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
