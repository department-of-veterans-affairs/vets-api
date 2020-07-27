# frozen_string_literal: true

module BGS
  module DependentEvents
    class Base
      def dependent_address(dependents_application, lives_with_vet, alt_address)
        return dependents_application.dig('veteran_contact_information', 'veteran_address') if lives_with_vet

        alt_address
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

      def serialize_dependent_result(
        participant,
        participant_relationship_type,
        family_relationship_type,
        optional_fields = {}
      )

        {
          vnp_participant_id: participant[:vnp_ptcpnt_id],
          participant_relationship_type_name: participant_relationship_type,
          family_relationship_type_name: family_relationship_type,
          begin_date: optional_fields[:begin_date],
          end_date: optional_fields[:end_date],
          event_date: optional_fields[:event_date],
          marriage_state: optional_fields[:marriage_state],
          marriage_city: optional_fields[:marriage_city],
          divorce_state: optional_fields[:divorce_state],
          divorce_city: optional_fields[:divorce_city],
          marriage_termination_type_code: optional_fields[:marriage_termination_type_code],
          living_expenses_paid_amount: optional_fields[:living_expenses_paid],
          type: optional_fields[:type]
        }
      end
    end
  end
end
