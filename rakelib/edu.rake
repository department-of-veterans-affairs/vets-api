# frozen_string_literal: true
namespace :edu do
  desc 'Given a confirmation number, print a spool file entry'
  task :print, [:id] => [:environment] do |_t, args|
    raise 'need to give an id. edu:print[{id}]' if args[:id].blank?
    id = args[:id].gsub(/\D/, '').to_i
    app = EducationBenefitsClaim.find(id)
    puts EducationForm::Forms::Base.build(app).text
  end

  desc 'delete saved claims that have no associated education benefits claim'
  task delete_saved_claims: :environment do
    saved_claims = SavedClaim::EducationBenefits.eager_load(:education_benefits_claim)
                                                .where(education_benefits_claims: { id: nil })

    puts "Deleting #{saved_claims.count} saved claims"
    saved_claims.delete_all
  end
end
