# frozen_string_literal: true

require_relative '../../../lib/veteran_enrollment_system/form1095_b/service'
require_relative '../../../lib/veteran_enrollment_system/enrollment_periods/service'

module V0
  class Form1095BsController < ApplicationController
    service_tag 'form-1095b'
    before_action { authorize :form1095, :access? }

    def available_forms
      if Flipper.enabled?(:fetch_1095b_from_enrollment_system, current_user)
        periods = VeteranEnrollmentSystem::EnrollmentPeriods::Service.new.get_enrollment_periods(icn: current_user.icn)
        years = VeteranEnrollmentSystem::Form1095B::Form1095B.available_years(periods)
        # last_updated is not used on front end.
        forms = years.map { |year| { year:, last_updated: nil } }
      else
        current_form = Form1095B.find_by(veteran_icn: current_user.icn, tax_year: Form1095B.current_tax_year)
        forms = current_form.nil? ? [] : [{ year: current_form.tax_year, last_updated: current_form.updated_at }]
      end
      render json: { available_forms: forms }
    end

    # these should probably have year limits on them with the new api to prevent people spamming in the inspector
    def download_pdf
      file_name = "1095B_#{tax_year}.pdf"
      send_data form.pdf_file, filename: file_name, type: 'application/pdf', disposition: 'inline'
    end

    def download_txt
      file_name = "1095B_#{tax_year}.txt"
      send_data form.txt_file, filename: file_name, type: 'text/plain', disposition: 'inline'
    end

    private

    def form
      if Flipper.enabled?(:fetch_1095b_from_enrollment_system, current_user)
        service = VeteranEnrollmentSystem::Form1095B::Service.new
        form_data = service.get_form_by_icn(icn: current_user[:icn], tax_year:)
        VeteranEnrollmentSystem::Form1095B::Form1095B.parse(form_data)
      else
        return current_form_record if current_form_record.present?

        Rails.logger.error("Form 1095-B for #{tax_year} not found", user_uuid: current_user&.uuid)
        raise Common::Exceptions::RecordNotFound, tax_year
      end
    end

    def current_form_record
      @current_form_record ||= Form1095B.find_by(veteran_icn: current_user[:icn], tax_year:)
    end

    def download_params
      params.permit(:tax_year)
    end

    def tax_year
      download_params[:tax_year]
    end
  end
end
