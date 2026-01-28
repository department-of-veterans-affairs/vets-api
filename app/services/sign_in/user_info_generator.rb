# frozen_string_literal: true

module SignIn
  class UserInfoGenerator
    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def perform
      SignIn::UserInfo.new(sub:, ial:, aal:, csp_type:, csp_uuid:, email:, first_name:, last_name:, full_name:,
                           address_street1:, address_street2:, address_city:, address_state:, address_country:,
                           address_postal_code:, phone_number:, person_types:, icn:, sec_id:, edipi:, mhv_ien:,
                           npi_id:, cerner_id:, corp_id:, birls:, gcids:, birth_date:, ssn:, gender:)
    end

    private

    def sub                 = user_verification.credential_identifier
    def ial                 = user_verification.verified? ? Constants::Auth::IAL_TWO : Constants::Auth::IAL_ONE
    def aal                 = AAL::LOGIN_GOV_AAL2
    def csp_uuid            = user_verification.credential_identifier
    def email               = user.user_verification&.user_credential_email&.credential_email
    def last_name           = user.last_name
    def first_name            = user.first_name
    def full_name           = user.full_name_normalized.values.compact.join(' ')
    def birth_date          = user.birth_date
    def ssn                 = user.ssn
    def gender              = user.gender
    def address_street1     = user.address[:street]
    def address_street2     = user.address[:street2]
    def address_city        = user.address[:city]
    def address_state       = user.address[:state]
    def address_country     = user.address[:country]
    def address_postal_code = user.address[:postal_code]
    def phone_number        = user.home_phone
    def person_types        = user.person_types&.join('|') || ''
    def icn                 = user.icn
    def sec_id              = user.sec_id
    def edipi               = user.edipi
    def mhv_ien             = user.mhv_ien
    def npi_id              = user.npi_id
    def cerner_id           = user.cerner_id
    def corp_id             = user.participant_id
    def birls               = user.birls_id
    def gcids               = filter_gcids.join('|')

    def user_verification
      @user_verification ||= user.user_verification
    end

    def csp_type
      case user_verification.credential_type
      when 'idme'
        MPI::Constants::IDME_IDENTIFIER
      when 'logingov'
        MPI::Constants::LOGINGOV_IDENTIFIER
      end
    end

    def filter_gcids
      return [] if user.mpi_gcids.blank?

      user.mpi_gcids.filter do |gcid|
        code = gcid.to_s.split('^', 4)[2]
        next false if code.blank?

        UserInfo::ALLOWED_GCID_CODES.key?(code) || code.match?(UserInfo::NUMERIC_GCID_CODE)
      end
    end
  end
end
