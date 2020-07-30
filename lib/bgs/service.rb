# frozen_string_literal: true

module BGS
  class Service
    # include BGS::Exceptions::BGSErrors

    def initialize(user)
      @user = user
    end

    def create_child_school(child_school_params)
      service.vnp_child_school.child_school_create(child_school_params.merge(bgs_auth))
    end

    def create_child_student(child_student_params)
      service.vnp_child_student.child_student_create(child_student_params.merge(bgs_auth))
    end

    def bgs_auth
      {
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application,
        ssn: @user[:ssn] # Just here to make the mocks work
      }
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: @user[:icn], external_key: @user[:external_key])
    end
  end
end
