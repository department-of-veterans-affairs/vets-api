# frozen_string_literal: true

require_relative '../../../lib/veteran_enrollment_system/form1095_b/service'
require_relative '../../../lib/veteran_enrollment_system/enrollment_periods/service'

module V0
  class Form1095BsController < ApplicationController
    service_tag 'form-1095b'
    before_action { authorize :form1095, :access? }
    before_action :validate_year, only: %i[download_pdf download_txt], if: -> { fetch_from_enrollment_system? }
    before_action :validate_pdf_template, only: %i[download_pdf], if: -> { fetch_from_enrollment_system? }
    before_action :validate_txt_template, only: %i[download_txt], if: -> { fetch_from_enrollment_system? }

    def available_forms
      if fetch_from_enrollment_system?
        forms = fetch_enrollment_periods
      else
        current_form = Form1095B.find_by(veteran_icn: current_user.icn, tax_year: Form1095B.current_tax_year)
        forms = current_form.nil? ? [] : [{ year: current_form.tax_year, last_updated: current_form.updated_at }]
      end
      render json: { available_forms: forms }
    end

    def download_pdf
      file_name = "1095B_#{tax_year}.pdf"
      send_data form.pdf_file, filename: file_name, type: 'application/pdf', disposition: 'inline'
    end

    def download_txt
      file_name = "1095B_#{tax_year}.txt"
      send_data form.txt_file, filename: file_name, type: 'text/plain', disposition: 'inline'
    end

    private

    def fetch_enrollment_periods
      periods = VeteranEnrollmentSystem::EnrollmentPeriods::Service.new.get_enrollment_periods(icn: current_user.icn)
      years = model_class.available_years(periods)
      forms = years.map { |year| { year:, last_updated: nil } } # last_updated is not used on front end.
      forms.sort_by! { |f| f[:year] }
    rescue Common::Exceptions::ResourceNotFound
      [] # if user is not known by enrollment system, return empty list
    end

    def form
      if fetch_from_enrollment_system?
        service = VeteranEnrollmentSystem::Form1095B::Service.new
        form_data = service.get_form_by_icn(icn: current_user[:icn], tax_year:)
        model_class.parse(form_data)
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

    def validate_year
      unless Integer(tax_year).between?(*model_class.available_years_range)
        raise Common::Exceptions::UnprocessableEntity, detail: "1095-B for tax year #{tax_year} not supported",
                                                       source: self.class.name
      end
    end

    def validate_txt_template
      unless File.exist?(model_class.txt_template_path(tax_year))
        raise Common::Exceptions::UnprocessableEntity, detail: "1095-B for tax year #{tax_year} not supported",
                                                       source: self.class.name
      end
    end

    def validate_pdf_template
      unless File.exist?(model_class.pdf_template_path(tax_year))
        raise Common::Exceptions::UnprocessableEntity, detail: "1095-B for tax year #{tax_year} not supported",
                                                       source: self.class.name
      end
    end

    def model_class
      VeteranEnrollmentSystem::Form1095B::Form1095B
    end

    def fetch_from_enrollment_system?
      Flipper.enabled?(:fetch_1095b_from_enrollment_system, current_user)
    end
  end
end
