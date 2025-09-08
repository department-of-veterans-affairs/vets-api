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
            official['role']['displayRole'] = role['level'] == 'other' ? role['other'] : role['level']
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
              form_data["proprietaryProfitConflicts#{index}"] = {
                'employeeName' => "#{individuals['first']} #{individuals['last']}",
                'association' => individuals['individualAssociationType']&.upcase
              }
            end
          end

          def process_all_proprietary_conflicts(form_data)
            return unless form_data['allProprietaryProfitConflicts']

            conflicts = form_data['allProprietaryProfitConflicts'].first(2)
            conflicts.each_with_index do |conflict, index|
              official = conflict['certifyingOfficial']
              form_data["allProprietaryProfitConflicts#{index}"] = {
                'officialName' => "#{official['first']} #{official['last']}",
                'fileNumber' => conflict['fileNumber'],
                'enrollmentDateRange' => conflict['enrollmentPeriod']['from'],
                'enrollmentDateRangeEnd' => conflict['enrollmentPeriod']['to']
              }
            end
          end

          def convert_boolean_to_yes_no(value)
            return 'N/A' if value.nil?

            value ? 'YES' : 'NO'
          end
        end
      end
    end
  end
end
