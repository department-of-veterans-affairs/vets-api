# frozen_string_literal: true
module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      education_benefits_claim = EducationBenefitsClaim.new(education_benefits_claim_params)

      unless education_benefits_claim.save
        validation_error = education_benefits_claim.errors.full_messages.join(', ')

        Raven.tags_context(validation: 'education_benefits_claim')
        Raven.capture_exception(validation_error)

        logger.error(validation_error)
        raise Common::Exceptions::ValidationErrors, education_benefits_claim
      end

      render(json: education_benefits_claim)
    end

    # TODO: This is hidden behind a flag in the routes, but it's duplicated here for some
    # defense in depth. This functionality should not be included once EducationForm is
    # released in production, but rather should be available in a dedicated admin interface
    def show
      return redirect_to(root_path) unless FeatureFlipper.show_education_benefit_form?

      form = EducationBenefitsClaim.find(params[:id])
      txt = ::EducationForm::CreateDailySpoolFiles.new.format_application(form.open_struct_form)
      render text: txt
    end

    def daily_file
      return redirect_to(root_path) unless FeatureFlipper.show_education_benefit_form?
      known_tmp_path = Rails.root.join('tmp', 'spool_files')
      archive_file = known_tmp_path.join('spool.tar')

      ::EducationForm::CreateDailySpoolFiles.new.perform
      Dir.chdir(known_tmp_path.to_s) do
        system('tar -cf spool.tar *.spl')
      end
      send_file archive_file, filename: 'spool.tar'
    end

    private

    def education_benefits_claim_params
      params.require(:education_benefits_claim).permit(:form)
    end
  end
end
