# frozen_string_literal: true

module BGS
  class StudentSchool < Service
    def initialize(proc_id:, vnp_participant_id:, payload:, user:)
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @dependents_application = payload['dependents_application']

      super(user)
    end

    def create
      create_child_school
      create_child_student
    end

    private

    def create_child_school
      with_multiple_attempts_enabled do
        service.vnp_child_school.child_school_create(
          child_school.params_for_686c
        )
      end
    end

    def create_child_student
      with_multiple_attempts_enabled do
        service.vnp_child_student.child_student_create(
          child_student.params_for_686c
        )
      end
    end

    def child_school
      @child_student = BGS::Vnp::ChildSchool.new(
        @dependents_application,
        proc_participant_auth
      )
    end

    def child_student
      @child_student = BGS::Vnp::ChildStudent.new(
        @dependents_application,
        proc_participant_auth
      )
    end

    def proc_participant_auth
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id: @vnp_participant_id
      }.merge(bgs_auth)
    end
  end
end
