# frozen_string_literal: true

require_relative 'service'

module BGS
  class StudentSchool
    def initialize(proc_id:, vnp_participant_id:, payload:, user:, student:)
      @user = user
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @dependents_application = payload['dependents_application']
      @student = student
    end

    def create
      assign_program_and_govt_paid_tuitn_ind
      child_school = BGSDependents::ChildSchool.new(@proc_id, @vnp_participant_id, @student)
      child_student = BGSDependents::ChildStudent.new(@proc_id, @vnp_participant_id, @student)

      bgs_service.create_child_school(child_school.params_for_686c)
      bgs_service.create_child_student(child_student.params_for_686c)
    end

    private

    def get_program(parent_object)
      return nil if parent_object.blank?

      type_mapping = {
        'ch35' => 'Chapter 35',
        'fry' => 'Fry Scholarship',
        'feca' => 'FECA'
      }
      # sanitize object of false values
      parent_object = parent_object.compact_blank
      return nil if parent_object.blank?

      # concat and sanitize values not in type_mapping
      parent_object.map { |key, _value| type_mapping[key] }.compact_blank.join(', ')
    end

    def assign_program_and_govt_paid_tuitn_ind
      program = get_program(@student&.dig('type_of_program_or_benefit'))
      if program.present? && @student['school_information'].present?
        name = [program, @student&.dig('school_information', 'name')].compact_blank.join(', ')
        @student['type_of_program_or_benefit'] = name.presence
        @student['school_information']['name'] = name.presence
        @student['tuition_is_paid_by_gov_agency'] = true
      end
    end

    def bgs_service
      @service ||= BGS::Service.new(@user)
    end
  end
end
