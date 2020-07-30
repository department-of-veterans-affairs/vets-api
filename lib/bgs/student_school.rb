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
      bgs_service.create_child_school(submit_params(child_school))
      bgs_service.create_child_student(submit_params(child_student))
    end

    private

    def child_school
      @child_student = BGSDependents::ChildSchool.new(
        @dependents_application
      )
    end

    def child_student
      @child_student = BGSDependents::ChildStudent.new(
        @dependents_application
      )
    end

    def submit_params(child_object)
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id: @vnp_participant_id
      }.merge(child_object.params_for_686c)
    end

    def bgs_service
      @service ||= BGS::Service.new(@user)
    end
  end
end
