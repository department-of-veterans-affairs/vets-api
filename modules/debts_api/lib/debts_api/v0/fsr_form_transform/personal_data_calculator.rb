# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class PersonalDataCalculator
        include ::FsrFormTransform::Utils
        def initialize(form)
          @form = form
          @personal_data = form['personal_data']
        end

        def get_personal_data
          {
            'veteranFullName' => veteran_full_name,
            'spouseFullName' => spouse_full_name,
            'address' => address,
            'telephoneNumber' => telephone_number,
            'dateOfBirth' => date_of_birth,
            'married' => married?,
            'agesOfOtherDependents' => dependents_ages,
            'employmentHistory' => veteran_employment_records + spouse_employment_records
          }
        end

        def name_str
          first = @personal_data.dig('veteran_full_name', 'first')
          middle = @personal_data.dig('veteran_full_name', 'middle')
          last = @personal_data.dig('veteran_full_name', 'last')
          "#{first} #{middle} #{last}"
        end

        private

        def veteran_employment_records
          records = @personal_data.dig('employment_history', 'veteran', 'employment_records') || []
          transform_records_for('VETERAN', records)
        end

        def spouse_employment_records
          records = @personal_data.dig('employment_history', 'spouse', 'sp_employment_records') || []
          transform_records_for('SPOUSE', records)
        end

        def transform_records_for(employee, records)
          records.map do |record|
            {
              'veteranOrSpouse' => employee,
              'occupationName' => record['type'],
              'from' => sanitize_date_string(record['from']),
              'to' => sanitize_date_string(record['to']),
              'present' => record['is_current'],
              'employerName' => record['employer_name'],
              'employerAddress' => {
                'addresslineOne' => '',
                'addresslineTwo' => '',
                'addresslineThree' => '',
                'city' => '',
                'stateOrProvince' => '',
                'zipOrPostalCode' => '',
                'countryName' => ''
              }
            }
          end
        end

        def veteran_full_name
          {
            'first' => @personal_data['veteran_full_name']['first'],
            'middle' => @personal_data['veteran_full_name']['middle'] || '',
            'last' => @personal_data['veteran_full_name']['last']
          }
        end

        def address
          {
            'addresslineOne' => @personal_data['veteran_contact_information']['address']['address_line1'],
            'addresslineTwo' => @personal_data['veteran_contact_information']['address']['address_line2'] || '',
            'addresslineThree' => @personal_data['veteran_contact_information']['address']['address_line3'] || '',
            'city' => @personal_data['veteran_contact_information']['address']['city'],
            'stateOrProvince' => @personal_data['veteran_contact_information']['address']['state_code'],
            'zipOrPostalCode' => @personal_data['veteran_contact_information']['address']['zip_code'],
            'countryName' => @personal_data['veteran_contact_information']['address']['country_code_iso2']
          }
        end

        def telephone_number
          area_code = @personal_data['veteran_contact_information']['mobile_phone']['area_code']
          phone_number = @personal_data['veteran_contact_information']['mobile_phone']['phone_number']

          "(#{area_code}) #{phone_number[0..2]}-#{phone_number[3..6]}"
        end

        def date_of_birth
          Date.parse(@personal_data['date_of_birth']).strftime('%m/%d/%Y')
        end

        def spouse_full_name
          if married?
            {
              'first' => @personal_data['spouse_full_name']['first'],
              'middle' => @personal_data['spouse_full_name']['middle'] || '',
              'last' => @personal_data['spouse_full_name']['last'] || ''
            }
          else
            {
              'first' => '',
              'middle' => '',
              'last' => ''
            }
          end
        end

        def dependents_ages
          has_dependents = !@personal_data['dependents'].empty?

          if has_dependents
            @personal_data['dependents'].pluck('dependent_age')
          else
            []
          end
        end

        def married?
          @form['questions']['is_married']
        end
      end
    end
  end
end
