# frozen_string_literal: true

require_relative 'service'

module BGS
  class DependentHigherEdAttendance
    def initialize(proc_id:, payload:, user:, student:)
      @proc_id = proc_id
      @payload = payload
      @dependents_application = payload['dependents_application']
      @dependents = {}
      @user = user
      @student = student
    end

    def create
      report_adult_children_attending_school if @student.present?
    end

    def report_adult_children_attending_school
      adult_attending_school = BGSDependents::AdultChildAttendingSchool.new(@student)
      formatted_info = adult_attending_school.format_info
      participant = bgs_service.create_participant(@proc_id)

      bgs_service.create_person(person_params(adult_attending_school, participant, formatted_info))
      send_address(adult_attending_school, participant, adult_attending_school.address)
      @dependents = adult_attending_school.serialize_dependent_result(
        participant,
        'Child',
        formatted_info['relationship_to_student'] || 'Biological',
        {
          type: '674',
          dep_has_income_ind: formatted_info['dependent_income']
        }
      )
    end

    def person_params(calling_object, participant, dependent_info)
      calling_object.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], dependent_info)
    end

    def send_address(calling_object, participant, address_info)
      address = calling_object.generate_address(address_info)
      address_params = calling_object.create_address_params(@proc_id, participant[:vnp_ptcpnt_id], address)

      bgs_service.create_address(address_params)
    end

    def bgs_service
      @bgs_service ||= BGS::Service.new(@user)
    end
  end
end
