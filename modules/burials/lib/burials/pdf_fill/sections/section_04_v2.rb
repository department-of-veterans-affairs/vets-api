# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section IV: Final Resting Place Information
    class Section4V2 < Section
      # rubocop:disable Layout/LineLength
      # Section configuration hash
      KEY = {
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        # 21
        'finalRestingPlace' => { # break into yes/nos
          'location' => {
            key: 'form1[0].#subform[95].RadioButtonList[6]'
          },
          'other' => {
            limit: 58,
            question_num: 21,
            question_label: "Place Of Burial Plot, Interment Site, Or Final Resting Place Of Deceased Veteran's Remains",
            question_text: "PLACE OF BURIAL PLOT, INTERMENT SITE, OR FINAL RESTING PLACE OF DECEASED VETERAN'S REMAINS",
            key: 'form1[0].#subform[83].#subform[84].PLACE_OF_DEATH[0]'
          }
        },
        # 22
        'hasNationalOrFederal' => {
          key: 'form1[0].#subform[37].FederalCemetery[0]'
        },
        'name' => {
          key: 'form1[0].#subform[37].FederalCemeteryName[0]',
          question_num: 22,
          question_label: 'Name Of National Or Federal Cemetery',
          question_text: 'NAME OF NATIONAL OR FEDERAL CEMETERY',
          limit: 50
        },
        # 23
        'cemetaryLocationRadio' => {
          key: 'form1[0].#subform[95].RadioButtonList[8]'
        },
        'stateCemeteryOrTribalTrustName' => {
          key: 'form1[0].#subform[37].StateCemeteryOrTribalTrustName[2]',
          question_num: 23,
          question_label: 'Name Of State Cemetery Or Tribal Trust Land',
          question_text: 'NAME OF STATE CEMETERY OR TRIBAL TRUST LAND',
          limit: 33
        },
        'stateCemeteryOrTribalTrustZip' => {
          key: 'form1[0].#subform[37].StateCemeteryOrTribalTrustZip[2]'
        },
        # 24A
        'hasGovtContributions' => {
          key: 'form1[0].#subform[37].GovContribution[0]'
        },
        # 24B
        'amountGovtContribution' => {
          key: 'form1[0].#subform[37].AmountGovtContribution[0]',
          question_num: 24,
          question_suffix: 'B',
          dollar: true,
          question_label: 'Amount Of Government Or Employer Contribution',
          question_text: 'AMOUNT OF GOVERNMENT OR EMPLOYER CONTRIBUTION',
          limit: 5
        },
        # 25
        'plotExpenseResponsibility' => {
          key: 'form1[0].#subform[95].RadioButtonList[11]'
        }
      }.freeze
      # rubocop:enable Layout/LineLength

      ##
      # Expands the form data for Section 4.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        form_data['hasNationalOrFederal'] = select_radio(form_data['nationalOrFederal'])
        form_data['hasGovtContributions'] = select_radio(form_data['govtContributions'])

        # special case for transportation being the only option selected.
        final_resting_place = form_data.dig('finalRestingPlace', 'location')
        if final_resting_place.present?
          form_data['finalRestingPlace']['location'] = Constants::RESTING_PLACES[final_resting_place]
        end

        set_state_to_no_if_national(form_data)
        expand_cemetery_location(form_data)
        expand_location_question(form_data)
        expand_tribal_land_location(form_data)
        format_currency_spacing(form_data)

        form_data['plotExpenseResponsibility'] = select_radio(form_data['plotExpenseResponsibility'])

        form_data
      end

      ##
      # Expands cemetery location details by extracting relevant information
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_cemetery_location(form_data)
        cemetery_location = form_data['cemeteryLocation']
        cemetery_location_question = form_data['cemetaryLocationQuestion']
        return unless cemetery_location.present? && cemetery_location_question == 'cemetery'

        form_data['stateCemeteryOrTribalTrustName'] = cemetery_location['name'] if cemetery_location['name'].present?
        form_data['stateCemeteryOrTribalTrustZip'] = cemetery_location['zip'] if cemetery_location['zip'].present?
      end

      ##
      # Expands the 'cemetaryLocationQuestion' to other form_data fields
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_location_question(form_data)
        cemetery_location = form_data['cemetaryLocationQuestion']
        if cemetery_location.present?
          form_data['cemetaryLocationRadio'] =
            Constants::CEMETERY_LOCATION[cemetery_location]
        end
      end

      ##
      # Expands tribal land location details by extracting relevant information
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_tribal_land_location(form_data)
        cemetery_location = form_data['tribalLandLocation']
        cemetery_location_question = form_data['cemetaryLocationQuestion']
        return unless cemetery_location.present? && cemetery_location_question == 'tribalLand'

        form_data['stateCemeteryOrTribalTrustName'] = cemetery_location['name'] if cemetery_location['name'].present?
        form_data['stateCemeteryOrTribalTrustZip'] = cemetery_location['zip'] if cemetery_location['zip'].present?
      end

      ##
      # Adjusts the spacing of the 'amountGovtContribution' value by right-justifying it
      #
      # @return [void, nil]
      def format_currency_spacing(form_data)
        return if form_data['amountGovtContribution'].blank?

        form_data['amountGovtContribution'] = form_data['amountGovtContribution'].rjust(5)
      end

      ##
      # Sets the 'cemeteryLocationQuestion' field to 'none' if the 'nationalOrFederal' field is present and truthy.
      #
      # @return [void, nil]
      def set_state_to_no_if_national(form_data)
        national = form_data['nationalOrFederal']
        form_data['cemetaryLocationQuestion'] = 'none' if national
      end
    end
  end
end
