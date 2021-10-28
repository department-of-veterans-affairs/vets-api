# frozen_string_literal: true

FactoryBot.define do
  factory :dependent_relationships, class: 'Array' do
    initialize_with do
      [
        {
          # death
          vnp_participant_id: '29236',
          participant_relationship_type_name: 'Spouse',
          family_relationship_type_name: 'Spouse',
          begin_date: nil,
          end_date: nil,
          event_date: '2001-03-02T00:00:00-05:00',
          marriage_state: nil,
          marriage_city: nil,
          divorce_state: nil,
          divorce_city: nil,
          marriage_termination_type_code: 'Death',
          living_expenses_paid_amount: nil,
          type: 'death'
        },
        {
          # spouse
          vnp_participant_id: '29237',
          participant_relationship_type_name: 'Spouse',
          family_relationship_type_name: 'Spouse',
          begin_date: nil,
          end_date: nil,
          event_date: nil,
          marriage_state: 'FL',
          marriage_city: 'Tampa',
          divorce_state: nil,
          divorce_city: nil,
          marriage_termination_type_code: nil,
          living_expenses_paid_amount: nil,
          type: 'spouse'
        },
        {
          # ex-spouse
          vnp_participant_id: '29238',
          participant_relationship_type_name: 'Spouse',
          family_relationship_type_name: 'Ex-Spouse',
          begin_date: '2001-01-01T00:00:00-05:00',
          end_date: '2013-01-01T00:00:00-05:00',
          event_date: nil,
          marriage_state: 'FL',
          marriage_city: 'Tampa',
          divorce_state: nil,
          divorce_city: nil,
          marriage_termination_type_code: nil,
          living_expenses_paid_amount: nil
        },
        {
          #  child
          vnp_participant_id: '29239',
          participant_relationship_type_name: 'Child',
          family_relationship_type_name: 'Biological',
          begin_date: nil,
          end_date: nil,
          event_date: nil,
          marriage_state: nil,
          marriage_city: nil,
          divorce_state: nil,
          divorce_city: nil,
          marriage_termination_type_code: 'Death',
          living_expenses_paid_amount: nil,
          type: 'child'
        },
        {
          #  spouse's ex
          vnp_participant_id: '29240',
          participant_relationship_type_name: 'Spouse',
          family_relationship_type_name: 'Ex-Spouse',
          begin_date: '2001-01-01T00:00:00-05:00',
          end_date: '2013-01-01T00:00:00-05:00',
          event_date: nil,
          marriage_state: 'FL',
          marriage_city: 'Stuart',
          divorce_state: nil,
          divorce_city: nil,
          marriage_termination_type_code: 'Death',
          living_expenses_paid_amount: nil,
          type: 'spouse_marriage_history'
        }
      ]
    end
  end

  factory :step_children_relationships, class: 'Array' do
    initialize_with do
      [
        {
          vnp_participant_id: '150584',
          participant_relationship_type_name: 'Guardian',
          family_relationship_type_name: 'Other',
          begin_date: nil,
          end_date: nil,
          event_date: nil,
          marriage_state: nil,
          marriage_city: nil,
          marriage_country: nil,
          divorce_state: nil,
          divorce_city: nil,
          divorce_country: nil,
          marriage_termination_type_code: nil,
          living_expenses_paid_amount: '.5',
          child_prevly_married_ind: nil,
          guardian_particpant_id: '150583',
          type: 'stepchild'
        },
        {
          vnp_participant_id: '150585',
          participant_relationship_type_name: 'Guardian',
          family_relationship_type_name: 'Other',
          begin_date: nil,
          end_date: nil,
          event_date: nil,
          marriage_state: nil,
          marriage_city: nil,
          marriage_country: nil,
          divorce_state: nil,
          divorce_city: nil,
          divorce_country: nil,
          marriage_termination_type_code: nil,
          living_expenses_paid_amount: '.5',
          child_prevly_married_ind: nil,
          guardian_particpant_id: '150583',
          type: 'stepchild'
        }
      ]
    end
  end
end
