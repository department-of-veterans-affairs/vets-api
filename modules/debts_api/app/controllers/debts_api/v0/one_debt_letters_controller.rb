# frozen_string_literal: true
require 'debts_api/v0/one_debt_letter_service'

module DebtsApi
  module V0
    class OneDebtLettersController < ApplicationController
      service_tag 'debt-resolution'

      def download_pdf
        service = DebtsApi::V0::OneDebtLetterService.new(current_user)
        file_contents = service.get_pdf

        send_data file_contents, filename: file_name_for_pdf, type: 'application/pdf', disposition: 'attachment'
      end

      private

      def file_name_for_pdf
        "#{current_user.last_name}_#{Time.zone.now.strftime('%Y%m%d_%H%M%S')}_debt_letter.pdf"
      end
    end
  end
end
