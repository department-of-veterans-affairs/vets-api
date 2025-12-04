# frozen_string_literal: true

module V0
  module Chatbot
    class UsersController < SignIn::ServiceAccountApplicationController
      service_tag 'identity'

      before_action :authenticate_one_time_code
      rescue_from Common::Client::Errors::ClientError, with: :handle_invalid_code

      def show
        raise Common::Client::Errors::ClientError unless @icn

        user = build_user_from_icn
        profile_data = fetch_profile_data(user)

        render json: profile_data, status: :ok
      end

      private

      # Authentication
      def authenticate_one_time_code
        chatbot_code_container = ::Chatbot::CodeContainer.find(params[:code])
        @icn = chatbot_code_container&.icn
      ensure
        chatbot_code_container&.destroy
      end

      # need to build a minimal user object to leverage existing profile fetching logic
      def build_user_from_icn
        loa_level = extract_loa_from_mpi

        # only one loa_level is in the mpi profile, so we can set both current and highest to the same value
        user_identity = UserIdentity.new(
          uuid: SecureRandom.uuid,
          mhv_icn: @icn,
          loa: { current: loa_level, highest: loa_level }
        )

        ::User.new(uuid: user_identity.uuid).tap do |user|
          user.instance_variable_set(:@identity, user_identity)
        end
      end

      # keeping icn and preferred name at the base level for backwards compatibility
      # loa isn't currently used by virtual agent, but included for potential future use
      # contact information is nested for clarity
      def fetch_profile_data(user)
        {
          icn: @icn,
          preferred_name: extract_preferred_name,
          loa: user.loa[:current],
          contact_information: fetch_contact_information(user),
          date_of_birth: mpi_profile&.birth_date,
          ssn: mpi_profile&.ssn
        }
      end

      def extract_preferred_name
        mpi_profile&.preferred_names&.first || mpi_profile&.given_names&.first
      end

      # MPI Profile Access
      def mpi_profile
        @mpi_profile ||= fetch_mpi_profile
      end

      def fetch_mpi_profile
        MPI::Service.new.find_profile_by_identifier(
          identifier_type: MPI::Constants::ICN,
          identifier: @icn
        )&.profile
      rescue => e
        Rails.logger.error("Error fetching MPI profile for ICN #{@icn}: #{e.message}")
        nil
      end

      # LOA Extraction done so that it can be used in building the user object
      # we shouldn't have user contact information without LOA3
      # if we cant determine LOA from mpi, we assume LOA1
      def extract_loa_from_mpi
        return LOA::ONE unless mpi_profile&.person_types.present?

        idal_observation = find_idal_observation
        return LOA::ONE unless idal_observation

        loa_code = extract_loa_code(idal_observation)
        map_loa_code_to_constant(loa_code)
      end

      def find_idal_observation
        mpi_profile.person_types.find do |person_type|
          next false unless person_type.respond_to?(:nodes)

          person_type.nodes.any? do |node|
            idal_code_node?(node)
          end
        end
      end

      def idal_code_node?(node)
        node.respond_to?(:value) &&
          node.value == 'code' &&
          node.respond_to?(:attributes) &&
          node.attributes[:code] == 'IDAL'
      end

      def extract_loa_code(idal_observation)
        value_node = idal_observation.nodes.find do |node|
          node.respond_to?(:value) && node.value == 'value'
        end

        value_node&.attributes&.dig(:code)
      end

      def map_loa_code_to_constant(loa_code)
        case loa_code&.to_i
        when 3 then LOA::THREE
        when 2 then LOA::TWO
        when 1, nil then LOA::ONE
        end
      end

      # Contact Information
      def fetch_contact_information(user)
        return {} unless user.vet360_id.present? || user.icn.present?

        person = user.vet360_contact_info
        return {} if person.blank?

        build_contact_information_hash(user, person)
      rescue => e
        log_contact_information_error(e)
        {}
      end

      def build_contact_information_hash(user, person)
        {
          email: person.email,
          mailing_address: person.mailing_address,
          mobile_phone: person.mobile_phone,
          home_phone: person.home_phone,
          work_phone: person.work_phone
        }
      end

      def log_contact_information_error(error)
        Rails.logger.error(
          "Error fetching contact information for ICN #{@icn}: #{error.message}",
          { icn: @icn, error_class: error.class.name }
        )
      end

      # Error Handlers
      def handle_invalid_code
        render json: {
          error: 'invalid_request',
          error_description: 'Code is not valid.'
        }, status: :bad_request
      end
    end
  end
end
