# frozen_string_literal: true

module DebtsApi
  module V0
    class OneDebtLettersController < ApplicationController
      service_tag 'debt-resolution'

      def download_pdf
        veteran = mocked_veteran

        service = DebtsApi::V0::OneDebtLetterService.new(current_user)
        file_contents = service.get_pdf

        send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
      ensure
        File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
      end

      private

      def file_name_for_pdf
        "#{current_user.first_name}_#{current_user.last_name}_debt_letter.pdf"
      end

      def mocked_veteran
        {
          first_name_last_name: 'Travis Jones',
          file_number: '123456789', # TODO: get filenumber
          address: {
            address_line_1: '375 Mountainhigh Dr',
            address_line_2: nil,
            city_state_zip: 'Antioch TN 37013-5322'
          }
        }
      end
    end
  end
end
