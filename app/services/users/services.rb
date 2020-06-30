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
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
    def authorizations
      @list << BackendServices::RX if user.authorize :mhv_prescriptions, :access?
      @list << BackendServices::MESSAGING if user.authorize :mhv_messaging, :access?
      @list << BackendServices::HEALTH_RECORDS if user.authorize :mhv_health_records, :access?
      @list << BackendServices::MHV_AC if user.authorize :mhv_account_creation, :access?
      @list << BackendServices::EVSS_CLAIMS if user.authorize :evss, :access?
      @list << BackendServices::FORM526 if user.authorize :evss, :access_form526?
      @list << BackendServices::ADD_PERSON if user.authorize :mpi, :access_add_person?
      @list << BackendServices::USER_PROFILE if user.can_access_user_profile?
      @list << BackendServices::APPEALS_STATUS if user.authorize :appeals, :access?
      @list << BackendServices::ID_CARD if user.can_access_id_card?
      @list << BackendServices::IDENTITY_PROOFED if user.identity_proofed?
      @list << BackendServices::VET360 if user.can_access_vet360?
      @list += BetaRegistration.where(user_uuid: user.uuid).pluck(:feature)
      @list
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize

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
