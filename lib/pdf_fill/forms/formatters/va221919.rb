# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'

module PdfFill
  module Forms
    module Formatters
      class Va221919 < Base
        class << self
          def process_certifying_official(form_data)
            return unless form_data['certifyingOfficial']

            official = form_data['certifyingOfficial']
            official['fullName'] = "#{official['first']} #{official['last']}" if official['first'] && official['last']

            # Set display role
            return unless official['role']

            role = official['role']
            official['role']['displayRole'] = if role['level'] == 'other'
                                                role['other']&.upcase
                                              else
                                                role['level']&.upcase
                                              end
          end

          def process_institution_address(form_data)
            return unless form_data['institutionDetails'] && form_data['institutionDetails']['institutionAddress']

            address = form_data['institutionDetails']['institutionAddress']
            street = address['street']
            city_state_zip = "#{address['city']}, #{address['state']} #{address['postalCode']}"

            form_data['institutionDetails']['institutionAddress']['street'] = "#{street} #{city_state_zip}".strip
          end

          def convert_boolean_fields(form_data)
            form_data['isProprietaryProfit'] = convert_boolean_to_yes_no(form_data['isProprietaryProfit'])
            form_data['isProfitConflictOfInterest'] = convert_boolean_to_yes_no(form_data['isProfitConflictOfInterest'])
            form_data['allProprietaryConflictOfInterest'] =
              convert_boolean_to_yes_no(form_data['allProprietaryConflictOfInterest'])
          end

          def process_proprietary_conflicts(form_data)
            return unless form_data['proprietaryProfitConflicts']

            conflicts = form_data['proprietaryProfitConflicts'].first(2)
            conflicts.each_with_index do |conflict, index|
              individuals = conflict['affiliatedIndividuals']
              name = "#{individuals['first']} #{individuals['last']}"
              name += ", #{individuals['title']}" if individuals['title'].present?

              association = individuals['individualAssociationType']
              association = "#{association} employee" if %w[va saa].include?(association&.downcase)

              form_data["proprietaryProfitConflicts#{index}"] = {
                'employeeName' => name,
                'association' => association&.upcase
              }
            end
          end

          def process_all_proprietary_conflicts(form_data)
            return unless form_data['allProprietaryProfitConflicts']

            conflicts = form_data['allProprietaryProfitConflicts'].first(2)
            conflicts.each_with_index do |conflict, index|
              official = conflict['certifyingOfficial']
              name = "#{official['first']} #{official['last']}"
              name += ", #{official['title']}" if official['title'].present?

              form_data["allProprietaryProfitConflicts#{index}"] = {
                'officialName' => name,
                'fileNumber' => conflict['fileNumber'],
                'enrollmentDateRange' => format_date(conflict['enrollmentPeriod']['from']),
                'enrollmentDateRangeEnd' => format_date(conflict['enrollmentPeriod']['to'])
              }
            end
          end

          def process_is_authenticated(form_data)
            return unless form_data.key?('isAuthenticated')

            form_data['isAuthenticated'] = ('X' if form_data['isAuthenticated'])
          end

          def convert_boolean_to_yes_no(value)
            return 'N/A' if value.nil?

            value ? 'YES' : 'NO'
          end

          def format_date(date_str)
            return nil if date_str.blank?

            Date.parse(date_str).strftime('%m/%d/%Y')
          rescue
            date_str
          end
        end
      end
    end
  end
end
