# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/maps/key_map_1010_ez'

module PdfFill
  module Forms
    class Va1010ez < FormBase
      include Maps::KeyMap1010Ez

      GENDERS = { NB: '0', M: '1', F: '2', TM: '3', TF: '4', NA: '6', O: 'Off' }.freeze

      MARITAL_STATUS = ['Married', 'Never Married', 'Separated', 'Widowed', 'Divorced'].freeze

      ETHNICITY_CHOICES = %w[
        isAmericanIndianOrAlaskanNative
        isAsian
        isBlackOrAfricanAmerican
        isSpanishHispanicLatino
        isNativeHawaiianOrOtherPacificIslander
        isWhite
        hasDemographicNoAnswer
      ].freeze

      SERVICE_HISTORIES = %w[
        purpleHeartRecipient
        isFormerPow
        postNov111998Combat
        disabledInLineOfDuty
        swAsiaCombat
        vietnamService
        exposedToRadiation
        radiumTreatments
        campLejeune
      ].freeze

      def merge_fields(_options = {})
        @form_data['helpers'] = {
          'veteran' => {},
          'secondaryCaregiverOne' => {},
          'secondaryCaregiverTwo' => {}
        }

        merge_names('veteranFullName')
        merge_names('spouseFullName')
        merge_ethnicity_choices
        merge_place_of_birth
        merge_gender('gender')
        merge_gender('sigiGenders')
        merge_marital_status
        merge_service_histories
        merge_providers
        merge_spouse_address
        merge_dependents
        merge_financial_discloser
        merge_radio_buttons
        format_dates

        @form_data
      end

      private

      def merge_radio_buttons
        fields = %w[isMedicaidEligible isEnrolledMedicarePartA cohabitedLastYear wantsInitialVaContact]
        fields.each { |field| merge_radio_button(field, @form_data) }
      end

      def merge_names(type)
        name = @form_data[type]

        full_name_parts = [
          name['last'],
          name['first'],
          name['middle']
        ].compact.join(', ')

        @form_data['helpers'][type] = full_name_parts
      end

      def merge_gender(type = 'gender')
        value = @form_data[type] || 'O'

        @form_data['helpers'][type] = GENDERS[value.to_sym]
      end

      def merge_ethnicity_choices
        ETHNICITY_CHOICES.each do |choice|
          value = @form_data[choice]
          selected = value == true ? '1' : '2'

          @form_data['helpers'][choice] = selected
        end
      end

      def merge_marital_status
        value = @form_data['maritalStatus']

        MARITAL_STATUS.each_with_index do |status, i|
          if value.downcase == status&.downcase
            @form_data['helpers']['maritalStatus'] = (i + 1).to_s
            break
          end
        end
      end

      def merge_place_of_birth
        city = @form_data['cityOfBirth']
        state = @form_data['stateOfBirth']

        @form_data['helpers']['placeOfBirth'] = [city, state].join(', ')
      end

      def merge_service_histories
        SERVICE_HISTORIES.each { |history| merge_checkbox(history, @form_data) }
      end

      def merge_providers
        providers = @form_data['providers']
        provider = providers.first

        @form_data['helpers']['providers'] = provider
      end

      def merge_dependents
        dependents = @form_data['dependents']
        return if dependents.empty?

        dependent = dependents.first

        @form_data['helpers']['dependents'] = dependent

        format_date_for('dateOfBirth', dependent, 'dependents')
        format_date_for('becameDependent', dependent, 'dependents')
        merge_radio_button('dependentRelation', dependent, 'dependents')
        merge_radio_button('disabledBefore18', dependent, 'dependents')
        merge_radio_button('attendedSchoolLastYear', dependent, 'dependents')
      end

      def merge_spouse_address
        address = @form_data['spouseAddress']&.symbolize_keys

        full_address = format('%<street>s %<city>s, %<state>s %<postalCode>s', address)
        @form_data['helpers']['spouseAddress'] = full_address
      end

      def merge_financial_discloser
        disclosure = @form_data['discloseFinancialInformation']
        selected = disclosure == true ? 0 : 1

        @form_data['helpers']['discloseFinancialInformation'] = selected
      end

      def format_date_for(field, source, *path)
        date = source[field]
        date = Date.parse(date).strftime('%m/%d/%Y') if date
        assign_value(field, date, path)
      end

      def format_dates
        %w[
          veteranDateOfBirth lastEntryDate lastDischargeDate medicarePartAEffectiveDate
          spouseDateOfBirth dateOfMarriage
        ].each { |field| format_date_for(field, @form_data) }
      end

      def merge_radio_button(field, source, *path)
        selected = source[field] == true ? '1' : '2'

        assign_value(field, selected, path)
      end

      def form_data_helper(_field, path)
        form_data = path.empty? ? @form_data : @form_data.dig(*path)
        form_data.is_a?(Array) ? form_data.first : form_data
      end

      def assign_value(field, value, path)
        if path.empty?
          @form_data['helpers'][field] = value
          return
        end

        @form_data['helpers'].dig(*path)[field] = value
      end

      def merge_checkbox(field, source, *path)
        selected = source[field] == true ? 'YES' : 'NO'
        assign_value(field, selected, path)
      end
    end
  end
end
