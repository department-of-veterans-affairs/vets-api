# frozen_string_literal: true

module VAProfile
  module PersonSettings
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      configuration VAProfile::PersonSettings::Configuration

      STATSD_KEY_PREFIX = "#{VAProfile::Service::STATSD_KEY_PREFIX}.person_settings".freeze
      VA_PROFILE_ID_POSTFIX = '^PI^200VETS^USDVA'
      ICN_POSTFIX = '^NI^200M^USVHA'

      def get_person_options
        with_monitoring do
          verify_user!
          raw_response = perform(:get, person_options_request_path)
          PersonOptionsResponse.from(raw_response)
        end
      rescue Common::Client::Errors::ClientError => e
        if e.status == 404
          Rails.logger.warn('User not found in VAProfile', vaprofile_id: @user&.vet360_id)
          return PersonOptionsResponse.new(404, person_options: [])
        elsif e.status.to_i >= 400 && e.status.to_i < 500
          return PersonOptionsResponse.new(e.status, person_options: [])
        end

        handle_error(e)
      rescue => e
        handle_error(e)
      end

      def update_person_options(person_options_data)
        with_monitoring do
          verify_user!
          raw_response = perform(:post, person_options_request_path, person_options_data)
          PersonOptionsResponse.from(raw_response)
        end
      end

      private

      def verify_user!
        unless @user&.vet360_id.present? || @user&.icn.present?
          raise 'PersonSettings - Missing User ICN and VAProfile_ID'
        end

        Rails.logger.info(
          "PersonSettings User MVI Verified? : #{@user&.icn.present?}, VAProfile Verified? #{@user&.vet360_id.present?}"
        )
      end

      # Request path for person options endpoint formatted as person-options/v1/{oid}/{idWithAaid}
      def person_options_request_path
        "person-options/v1/#{MPI::Constants::VA_ROOT_OID}/#{ERB::Util.url_encode(vaprofile_id_with_aaid)}"
      end

      # User ID with AAID for VAProfile Requests
      # Prefer VAProfile_ID if present, otherwise use ICN
      def vaprofile_id_with_aaid
        return "#{@user.vet360_id}#{VA_PROFILE_ID_POSTFIX}" if @user.vet360_id.present?

        "#{@user.icn}#{ICN_POSTFIX}"
      end
    end
  end
end
