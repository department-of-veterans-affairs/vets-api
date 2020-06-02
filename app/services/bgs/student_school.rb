# frozen_string_literal: true

module BGS
  class StudentSchool < Base
    def initialize(proc_id:, vnp_participant_id:, payload:, user:)
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @dependents_application = payload['dependents_application']

      super(user)
    end

    def create
      child_school = create_child_school(
        @proc_id,
        @vnp_participant_id,
        @dependents_application
      )

      child_student = create_child_student(
        @proc_id,
        @vnp_participant_id,
        @dependents_application
      )

      [child_school, child_student]
    end
  end
end