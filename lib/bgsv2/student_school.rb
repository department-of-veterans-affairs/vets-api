# frozen_string_literal: true

require_relative 'service'

module BGSV2
  class StudentSchool
    def initialize(proc_id:, vnp_participant_id:, payload:, user:, student:)
      @user = user
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @dependents_application = payload['dependents_application']
      @student = student
      @is_v2 = Flipper.enabled?(:va_dependents_v2)
    end

    def create
      child_school = BGSDependents::ChildSchool.new(@dependents_application, @proc_id, @vnp_participant_id, @student)
      child_student = BGSDependents::ChildStudent.new(@dependents_application, @proc_id, @vnp_participant_id, @student)

      bgs_service.create_child_school(@is_v2 ? child_school.params_for_686c_v2 : child_school.params_for_686c)
      bgs_service.create_child_student(@is_v2 ? child_student.params_for_686c_v2 : child_student.params_for_686c)
    end

    private

    def bgs_service
      @service ||= BGS::Service.new(@user)
    end
  end
end
