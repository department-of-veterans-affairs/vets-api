# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestDecisionsController < ApplicationController


      def download_prefilled
        # Use mock sources to get the veteran demographic data
        veteran_data = get_mock_veteran_data
    
        pdf_handler = AccreditedRepresentativePortal::PdfHandler.new(
          '686_empty_form.pdf',
          'output_filled_form.pdf'
        )
    
        pdf_handler.fill_form(veteran_data)
      end

      private

      def get_mock_veteran_data
        {
          "F[0].Page_7[0].#subform[0].VeteranFirstName[0]" => "Jane",
          "F[0].Page_7[0].#subform[0].VeteranMiddleInitial1[0]" => "A",
          "F[0].Page_7[0].#subform[0].VeteranLastName[0]" => "Smith",
          "F[0].Page_7[0].#subform[0].Veterans_SocialSecurityNumber_FirstThreeNumbers[0]" => "111",
          "F[0].Page_7[0].#subform[0].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]" => "22",
          "F[0].Page_7[0].#subform[0].Veterans_SocialSecurityNumber_LastFourNumbers[0]" => "3333",
          "F[0].Page_7[0].#subform[0].VAFileNumber[0]" => "123456789",
          "F[0].Page_7[0].#subform[0].DOBmonth[0]" => "05",
          "F[0].Page_7[0].#subform[0].DOBday[0]" => "20",
          "F[0].Page_7[0].#subform[0].DOByear[0]" => "1980"
        }
      end
    end
  end
end