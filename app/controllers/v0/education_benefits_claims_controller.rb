# frozen_string_literal: true
module V0
  class EducationBenefitsClaimsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      education_benefits_claim = EducationBenefitsClaim.new(education_benefits_claim_params)

      raise Common::Exceptions::ValidationErrors, education_benefits_claim unless education_benefits_claim.save

      render(json: education_benefits_claim)
    end

    # TODO: This is hidden behind a flag in the routes, but it's duplicated here for some
    # defense in depth. This functionality should not be included once EducationForm is
    # released in production, but rather should be available in a dedicated admin interface
    def show
      (redirect_to root_path and return) unless (Rails.env.development? || (ENV['EDU_FORM_SHOW'] == 'true'))

      form = EducationBenefitsClaim.find(params[:id])
      txt = ::EducationForm::CreateDailySpoolFiles.new.format_application(form.open_struct_form)

      if params[:format] == 'tiff'
        text = Tempfile.new('edu_txt')
        tiff = Tempfile.new('edu_tiff')
        text.write(txt)
        text.close
        # we fully control these paths.
        `convert -bordercolor red -border 3 -append -density 100 -font CourierNew text:#{text.path} #{tiff.path}.tiff`
        send_file "#{tiff.path}.tiff", :disposition => 'inline', filename: '22-1990.tiff'
        text.close && text.unlink && tiff.close && tiff.unlink
      else
        render text: txt
      end
    end

    private

    def education_benefits_claim_params
      params.require(:education_benefits_claim).permit(:form)
    end
  end
end
