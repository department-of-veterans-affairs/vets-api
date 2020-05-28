# frozen_string_literal: true

module BGS
  class PeopleService
    def find_person_by_ptcpnt_id(current_user)
      external_key = current_user.common_name || current_user.email

      service = LighthouseBGS::Services.new(
        external_uid: current_user.icn,
        external_key: external_key
      )

      response = service.people.find_person_by_ptcpnt_id(current_user.participant_id)

      return {} if response.nil?

      response
    end
  end
end
