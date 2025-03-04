# frozen_string_literal: true

module DebtsApi
  class V0::OneDebtLetterService
    def initialize(user)
      @user = user
    end

    def get_pdf
      Prawn::Document.new(page_size: 'LETTER') do |pdf|
        add_and_format_logo(pdf)
      end.render
    end

    private

    def add_and_format_logo(pdf)
      logo_path = Rails.root.join('modules', 'debts_api', 'app', 'assets', 'images', 'va_logo.png')
      pdf.image logo_path, at: [(pdf.bounds.width / 2) - (250 / 2), pdf.cursor], width: 250

      Prawn::Document.new(page_size: 'LETTER').render

    end

    def vbs_service
      MedicalCopays::VBS::Service.build(user: current_user)
    end

    def dmc_service
      DebtManagementCenter::DebtsService.new(current_user)
    end
  end
end
