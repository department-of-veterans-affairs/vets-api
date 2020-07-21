# frozen_string_literal: true

module BGS
  module Helpers
    module Formatters
      CHILD_STATUS = {
        'child_under18' => 'Other',
        'step_child' => 'Stepchild',
        'biological' => 'Biological',
        'adopted' => 'Adopted Child',
        'disabled' => 'Other',
        'child_over18_in_school' => 'Other'
      }.freeze

      def format_child_marriage_info(child_marriage)
        {
          'event_date': child_marriage['date_married']
        }.merge(child_marriage['full_name']).with_indifferent_access
      end

      def format_child_not_attending(child)
        {
          event_date: child['date_child_left_school']
        }.merge(child['full_name']).with_indifferent_access
      end

      def format_stepchild_info(stepchild_info)
        {
          'living_expenses_paid': stepchild_info['living_expenses_paid'],
          'lives_with_relatd_person_ind': 'N'
        }.merge(stepchild_info['full_name']).with_indifferent_access
      end

      def format_child_info(child_info)
        {
          'ssn': child_info['ssn'],
          'family_relationship_type': CHILD_STATUS[child_info['child_status'].key(true)],
          'place_of_birth_state': child_info.dig('place_of_birth', 'state'),
          'place_of_birth_city': child_info.dig('place_of_birth', 'city'),
          'reason_marriage_ended': child_info.dig('previous_marriage_details', 'reason_marriage_ended'),
          'ever_married_ind': child_info['previously_married'] == 'Yes' ? 'Y' : 'N'
        }.merge(child_info['full_name']).with_indifferent_access
      end

      def format_death_info(death_info)
        {
          'death_date': death_info['date'],
          'vet_ind': 'N'
        }.merge(death_info['full_name'])
      end

      def format_divorce_info(report_divorce)
        {
          divorce_state: report_divorce.dig('location', 'state'),
          divorce_city: report_divorce.dig('location', 'city'),
          marriage_termination_type_code: report_divorce['reason_marriage_ended'],
          event_dt: report_divorce['date'],
          vet_ind: 'N',
          type: 'divorce'
        }.merge(report_divorce['full_name']).with_indifferent_access
      end

      def relationship_type(info)
        if info['dependent_type']
          return { participant: 'Guardian', family: 'Other' } if info['dependent_type'] == 'DEPENDENT_PARENT'

          {
            participant: info['dependent_type'].capitalize.gsub('_', ' '),
            family: info['dependent_type'].capitalize.gsub('_', ' ')
          }
        end
      end

      def format_674_info(name_and_ssn, was_married)
        {
          'ssn': name_and_ssn['ssn'],
          'birth_date': name_and_ssn['birth_date'],
          'ever_married_ind': was_married == true ? 'Y' : 'N'
        }.merge(name_and_ssn['full_name']).with_indifferent_access
      end

      # last of dependents helpers

      #  marriages helpers
      def format_marriage_info(spouse_information, lives_with_vet)
        marriage_info = {
          'ssn': spouse_information['ssn'],
          'birth_date': spouse_information['birth_date'],
          'ever_married_ind': 'Y',
          'martl_status_type_cd': lives_with_vet ? 'Married' : 'Separated',
          'vet_ind': spouse_information['is_veteran'] ? 'Y' : 'N'
        }.merge(spouse_information['full_name']).with_indifferent_access

        if spouse_information['is_veteran']
          marriage_info.merge!({ 'va_file_number': spouse_information['va_file_number'] })
        end

        marriage_info
      end

      def format_former_marriage_info(former_spouse)
        {
          'start_date': former_spouse['start_date'],
          'end_date': former_spouse['end_date'],
          'marriage_state': former_spouse.dig('start_location', 'state'),
          'marriage_city': former_spouse.dig('start_location', 'city'),
          'divorce_state': former_spouse.dig('start_location', 'state'),
          'divorce_city': former_spouse.dig('start_location', 'city'),
          'marriage_termination_type_code': former_spouse['reason_marriage_ended_other']
        }.merge(former_spouse['full_name']).with_indifferent_access
      end
    end
  end
end
