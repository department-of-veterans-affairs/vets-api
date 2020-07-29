# frozen_string_literal: true

module BGS
  class StudentSchool
    def initialize(proc_id:, vnp_participant_id:, payload:, user:)
      @user = user
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @dependents_application = payload['dependents_application']
    end

    def create
      bgs_service.create_child_school(child_school.params_for_686c)
      bgs_service.create_child_student(child_student.params_for_686c)
    end

    private

    def child_school
      @child_student = BGSDependents::ChildSchool.new(
        @dependents_application,
        proc_participant
      )
    end

    def child_student
      @child_student = BGSDependents::ChildStudent.new(
        @dependents_application,
        proc_participant
      )
    end

    def proc_participant
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id: @vnp_participant_id
      }
    end

    def bgs_service
      @service ||= BGS::Service.new(@user)
    end
  end
end
