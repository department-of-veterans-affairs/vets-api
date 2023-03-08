# frozen_string_literal: true

require 'backend_services'

module Users
  class Services
    attr_reader :user

    def initialize(user)
      @user = user
      @list = auth_free_services
    end

    # Checks if the initialized user has authorization to access any of the
    # below services.  Returns an array of services they have access to.
    #
    # @return [Array<String>] Array of names of services they have access to
    #
    def authorizations
      @list << BackendServices::RX if user.authorize :mhv_prescriptions, :access?
      @list << BackendServices::MESSAGING if user.authorize :mhv_messaging, :access?
      @list << BackendServices::HEALTH_RECORDS if user.authorize :mhv_health_records, :access?
      @list << BackendServices::EVSS_CLAIMS if user.authorize :evss, :access?
      @list << BackendServices::LIGHTHOUSE if user.authorize :lighthouse, :access?
      @list << BackendServices::FORM526 if user.authorize :evss, :access_form526?
      @list << BackendServices::ADD_PERSON_PROXY if user.authorize :mpi, :access_add_person_proxy?
      @list << BackendServices::USER_PROFILE if user.can_access_user_profile?
      @list << BackendServices::APPEALS_STATUS if user.authorize :appeals, :access?
      @list << BackendServices::ID_CARD if user.can_access_id_card?
      @list << BackendServices::IDENTITY_PROOFED if user.loa3?
      @list << BackendServices::VET360 if user.can_access_vet360?
      @list
    end

    private

    def auth_free_services
      [
        BackendServices::FACILITIES,
        BackendServices::HCA,
        BackendServices::EDUCATION_BENEFITS,
        BackendServices::SAVE_IN_PROGRESS,
        BackendServices::FORM_PREFILL
      ]
    end
  end
end
