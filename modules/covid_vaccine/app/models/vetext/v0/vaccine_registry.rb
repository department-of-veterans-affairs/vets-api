# frozen_string_literal: true

require 'active_model'
require 'common/models/form'
require 'common/exceptions'

module Vetext
  module V0
    class VaccineRegistry < Common::Form
      UNASSIGNABLE_ATTRIBUTES = %i[patient_icn sta3n sta6a authenticated].freeze

      attribute :patient_icn, String            # Not Assignable by params
      attribute :sta3n, String                  # Not Assignable by params
      attribute :sta6a, String                  # Not Assignable by params
      attribute :authenticated, Boolean         # Not Assignable by params
      attribute :vaccine_interest, String
      attribute :date_vaccine_received, String
      attribute :contact, Boolean
      attribute :contact_method, String
      attribute :reason_undecided, String
      attribute :phone, String
      attribute :email, String
      attribute :first_name, String             # Overridden by MVI
      attribute :middle_initial, String         # TODO: VEText MISSING ATTRIBUTE (needed for MVI lookup)
      attribute :last_name, String              # Overridden by MVI
      attribute :gender, String                 # TODO: VEText MISSING ATTRIBUTE (needed for MVI lookup)
      attribute :date_of_birth, String          # Overridden by MVI
      attribute :patient_ssn, String            # Overridden by MVI

      attr_reader :user

      def initialize(attributes, user = nil)
        super(attributes.except(*UNASSIGNABLE_ATTRIBUTES))
        @user = user || unauthenticated_user
      end

      def unauthenticated_user
        # TODO: figure out how to fetch from MVI when unauthenticated_user
        User.new(first_name: @first_name, last_name: @last_name, date_of_birth: @date_of_birth, ssn: @patient_ssn)
      end

      def first_name
        @user.first_name || @first_name
      end

      def middle_name
        @user.middle_name || @middle_name
      end

      def last_name
        @user.last_name || @last_name
      end

      def gender
        @user.gender || @gender
      end

      def date_of_birth
        @user.birth_date || @date_of_birth
      end

      def patient_ssn
        @user.ssn || @patient_ssn
      end

      def authenticated
        @user.loa3?
      rescue
        false
      end

      def patient_icn
        @user.icn
      rescue
        ''
      end

      def sta3n
        @user.mvi.profile.sta3n
      rescue
        ''
      end

      def sta6a
        @user.mvi.profile.sta6n
      rescue
        ''
      end
    end
  end
end
