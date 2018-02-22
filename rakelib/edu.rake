# frozen_string_literal: true

namespace :edu do
  desc 'Given a confirmation number, print a spool file entry'
  task :print, [:id] => [:environment] do |_t, args|
    raise 'need to give an id. edu:print[{id}]' if args[:id].blank?
    id = args[:id].gsub(/\D/, '').to_i
    app = EducationBenefitsClaim.find(id)
    puts EducationForm::Forms::Base.build(app).text
  end
end
