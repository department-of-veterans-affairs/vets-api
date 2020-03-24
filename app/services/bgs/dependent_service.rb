# frozen_string_literal: true

module BGS
  class DependentService
    def initialize(user)
      @user = user
    end

    def get_dependents
      service
        .claimants
        .find_dependents_by_participant_id(
          user.participant_id, user.ssn
        )
    end

    def modify_dependents
      delete_me_root = Rails.root.to_s
      delete_me_payload_file = File.read("#{delete_me_root}/app/services/bgs/possible_payload.json")
      payload = JSON.parse(delete_me_payload_file)
      # Step 1 create Proc
      # Step 2 Create ProcForm using ProcId from Step 1
      proc_id = create_proc_id_and_form

      # Step 3 Create FIRST Participant
      # Step 4 Create "Veteran" this is a 'Person' using ParticipantId generated from Step 3
      # person_create_response = vnp_person_create(create_ptcpnt_response["vnp_ptcpnt_id"])
      # Step 5 Create address for veteran pass in VNP participant id created in step 3
      # vnp_ptcpnt_addrs_create_response = vnp_ptcpnt_addrs_create(create_ptcpnt_response["vnp_ptcpnt_id"])

      veteran = PersonEntity.new(payload['veteran'], client, @user, proc_id, :veteran)
      veteran.vnp_create

      #####- loop through 6-8 for each dependent
      #   6. Create *NEXT* participant “Pass in corp participant id if it is obtainable”
      #   7. Create *Dependent* using participant-id from step 6
      #   8. Create address for dependent pass in participant-id from step 6
      #####

      # 9. Create Phone number for veteran or spouse(dependent?) pass in participant-id from step 3 or 6 (Maybe fire this off for each participant, we’ll look it up later)
      # vnp_ptcpnt_phone_create_response = vnp_ptcpnt_phone_create(create_ptcpnt_response["vnp_ptcpnt_id"])
      # vnp_ptcpnt_phone_create_response
      dependents = create_dependents(payload, proc_id)

      # 10. Create relationship pass in Veteran and dependent using respective participant-id (loop it for each dependent)
      # vnp_relationship_create(veteran, dependents)

      # ####-We’ll only do this for form number 674
      # 11. Create Child school (if there are kids)
      # 12. Create Child student (if there are kids)

      ####- Back in 686
      # 13. Create benefit claims in formation (no mention of id)
      # 14. Insert vnp benefit claim (created in step 13?)
      # 15. Update vip benefit claims information (pass Corp benefit claim id Created in step 14)
      # 16. Set vnpProcstateTypeCd to “ready “

    end

    private

    def client
      @client ||= LighthouseBGS::Services.new(
        external_uid: @user.icn,
        external_key: @user.email
      )
    end

    def create_proc_id_and_form
      vnp_response = vnp_proc_create
      vnp_proc_form_create(vnp_response[:vnp_proc_id])

      vnp_response[:vnp_proc_id]
    end

    def vnp_proc_create
      client.vnp_proc_v2.vnp_proc_create(
        vnp_proc_type_cd: 'COMPCLM',
        vnp_proc_state_type_cd: 'Ready',
        creatd_dt: '2020-02-25T09:59:16-06:00',
        last_modifd_dt: '2020-02-25T10:02:28-06:00',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application,
        submtd_dt: '2020-02-25T10:01:59-06:00',
        ssn: @user.ssn
      )
    end

    def vnp_proc_form_create(vnp_proc_id)
      client.vnp_proc_form.vnp_proc_form_create(
        vnp_proc_id: vnp_proc_id,
        form_type_cd: '21-686c',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        ssn: @user.ssn
      )
    end

    def create_dependents(payload, proc_id)
      spouse = PersonEntity.new(payload['veteran']['spouse'], client, @user, proc_id, :spouse)
      dependents = payload['veteran']['dependents'].map do |dependent|
        PersonEntity.new(dependent, client, @user, proc_id)
      end << spouse

      dependents.each { |person| person.vnp_create }

      dependents
    end

    # not implemented yet
    # def vnp_relationship_create(veteran, dependents)
    #   dependents.each do |dependent|
    #     client.vnp_ptcpnt_relationship.vnp_ptcpnt_relationship_create(
    #       veteran_id: veteran.participant['vnp_ptcpnt_id'],
    #       dependent_id: dependent.participant['vnp_ptcpnt_id']
    #     )
    #   end
    # end
  end
end

