# frozen_string_literal: true

module Swagger
  module Schemas
    class DependentsVerifications
      include Swagger::Blocks

      swagger_schema :DependentsVerifications do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :prompt_renewal, type: :boolean, example: true
          property :dependency_verifications, type: :array, example: [
            {
              "award_effective_date": '2016-06-01T00:00:00.000-05:00',
              "award_event_id": '185878',
              "award_type": 'CPL',
              "begin_award_event_id": '171629',
              "beneficiary_id": '13367440',
              "birthday_date": '1995-05-01T00:00:00.000-05:00',
              "decision_date": '2015-02-24T10:50:42.000-06:00',
              "decision_id": '125932',
              "dependency_decision_id": '53153',
              "dependency_decision_type": 'SCHATTT',
              "dependency_decision_type_description": 'School Attendance Terminates',
              "dependency_status_type": 'NAWDDEP',
              "dependency_status_type_description": 'Not an Award Dependent',
              "event_date": '2016-05-01T00:00:00.000-05:00',
              "first_name": 'JAMES',
              "full_name": 'JAMES E. SMITH',
              "last_name": 'SMITH',
              "middle_name": 'E',
              "modified_action": 'I',
              "modified_by": 'VHAISWWHITWT',
              "modified_date": '2015-02-24T10:50:41.000-06:00',
              "modified_location": '317',
              "modified_process": 'Awds/RBA-cp_dependdec_pkg.do_cre',
              "person_id": '600086386',
              "sort_date": '2015-02-24T10:50:42.000-06:00',
              "sort_order_number": '0',
              "veteran_id": '13367440',
              "veteran_indicator": 'N'
            }
          ]
        end
      end
    end
  end
end
