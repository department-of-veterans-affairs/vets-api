# frozen_string_literal: true

module Users
  class Profile
    include Common::Client::ServiceStatus

    HTTP_OK = 200
    HTTP_SOME_ERRORS = 296

    attr_reader :user, :scaffold

    def initialize(user)
      @user = validate!(user)
      @scaffold = Users::Scaffold.new([], HTTP_OK)
    end

    # Fetches and serializes all of the initialized user's profile data that
    # is returned in the '/v0/user' endpoint.
    #
    # If there are no external service errors, the status property is set to 200,
    # and the `errors` property is set to nil.
    #
    # If there *are* errors from any associated external services, the status
    # property is set to 296, and serialized versions of the errors are
    # added to the `errors` array.
    #
    # @return [Struct] A Struct composed of the fetched, serialized profile data.
    #
    def pre_serialize
      fetch_and_serialize_profile
      update_status_and_errors
      scaffold
    end

    private

    def validate!(user)
      raise Common::Exceptions::ParameterMissing.new('user'), 'user' unless user&.class == User

      user
    end

    def fetch_and_serialize_profile
      scaffold.account = account
      scaffold.profile = profile
      scaffold.vet360_contact_information = vet360_contact_information
      scaffold.va_profile = va_profile
      scaffold.veteran_status = veteran_status
      scaffold.in_progress_forms = in_progress_forms
      scaffold.prefills_available = prefills_available
      scaffold.services = services
    end

    def account
      {
        account_uuid: user.account_uuid
      }
    end

    def profile
      {
        email: user.email,
        first_name: user.first_name,
        middle_name: user.middle_name,
        last_name: user.last_name,
        birth_date: user.birth_date,
        gender: user.gender,
        zip: user.zip,
        last_signed_in: user.last_signed_in,
        loa: user.loa,
        multifactor: user.multifactor,
        verified: user.loa3?,
        sign_in: user.identity.sign_in,
        # FIXME: this wont be necessary after FE makes appropriate changes
        authn_context: user.authn_context.scan(/(myhealthevet|dslogon)/).flatten[0]
      }
    end

    def vet360_contact_information
      person = user.vet360_contact_info
      return {} if person.blank?

      {
        email: person.email,
        residential_address: person.residential_address,
        mailing_address: person.mailing_address,
        mobile_phone: person.mobile_phone,
        home_phone: person.home_phone,
        work_phone: person.work_phone,
        temporary_phone: person.temporary_phone,
        fax_number: person.fax_number
      }
    rescue StandardError => e
      scaffold.errors << Users::ExceptionHandler.new(e, 'Vet360').serialize_error
      nil
    end

    def va_profile
      status = user.va_profile_status

      if status == RESPONSE_STATUS[:ok]
        {
          status: status,
          birth_date: user.va_profile.birth_date,
          family_name: user.va_profile.family_name,
          gender: user.va_profile.gender,
          given_names: user.va_profile.given_names
        }
      else
        scaffold.errors << Users::ExceptionHandler.new(user.va_profile_error, 'MVI').serialize_error
        nil
      end
    end

    def veteran_status
      {
        status: RESPONSE_STATUS[:ok],
        is_veteran: user.veteran?,
        served_in_military: user.served_in_military?
      }
    rescue StandardError => e
      scaffold.errors << Users::ExceptionHandler.new(e, 'EMIS').serialize_error
      nil
    end

    def in_progress_forms
      user.in_progress_forms.map do |form|
        {
          form: form.form_id,
          metadata: form.metadata,
          last_updated: form.updated_at.to_i
        }
      end
    end

    def prefills_available
      return [] if user.identity.blank?

      FormProfile.prefill_enabled_forms
    end

    def services
      Users::Services.new(user).authorizations
    end

    def update_status_and_errors
      if scaffold.errors.present?
        scaffold.status = HTTP_SOME_ERRORS
      else
        scaffold.errors = nil
      end
    end
  end
end
