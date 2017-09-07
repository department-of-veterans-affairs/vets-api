# frozen_string_literal: true
require 'saml/user_attributes/base_decorator'

# TODO: remove these nocov comments when this is able to be tested.
#:nocov:
module SAML
  module UserAttributes
    # Sample attributes returned from MHV will look like the following:
    # {
    #   "mhv_icn"=>["1012853168V681485"],
    #   "mhv_profile"=> [
    #      "{
    #         \"accountType\":\"Premium\",
    #         \"availableServices\":{
    #            \"1\":\"Blue Button self entered data.\",
    #            \"11\":\"Blue Button (DoD) Military Service Information\"
    #         }
    #       }"
    #   ],
    #   "mhv_uuid"=>["1156060"]
    # }
    # Where mhv_profile is an escaped complex JSON object
    class MHV < BaseDecorator
      def mhv_icn
        attributes['mhv_icn']
      end

      # NOTE: this will always be a JSON object, see above
      def mhv_profile
        JSON.parse(attributes['mhv_profile'])
      end

      # NOTE: this is derived from mhv_profile which is a complex JSON object, see above
      def account_type
        mhv_profile['accountType']
      end

      # NOTE: this is derived from mhv_profile which is a complex JSON object, see above
      # QUESTION: Why is this premium user only listed to have Blue Button and not Rx or SM?
      def available_services
        mhv_profile['availableServices']
      end

      # NOTE: this UUID is usually a different length when it is coming from IDME
      # This might cause problems somewhere and we need to determine if padding is necessary
      # typically "mhv_uuid"=>["1156060"]
      # QUESTION: can we get ID.me to provide us with a uuid that conforms to our other UUID lengths?
      # QUESTION: can we even use this mhv profile id for querying the APIs? I think MHV should provide CorrelationID
      # QUESTION: maybe CorrelationID can somehow be derived from mhv profile id and ICN?
      def uuid
        attributes['mhv_uuid']
      end

      # NOTE: we do not get an email from MHV or from ID.me it's not clear if we can get the
      # one from ID.me and use that moving forward. We would probably need to make call into
      # MHV to update the email address using the Account Management API upon sign-in as well
      # FIXME: This is currently being set to a generic email for testing purposes
      # QUESTION: Can we possibly get the email that the user specifies when setting up with MHV?
      # If so we might be able to make a call to MHV to update the address at MHV upon sign-in
      # QUESTION: Or do we instead want to try to use whatever the email address is in MVI? According
      # to MHV, MVI email address is most likely outdated / not preferred.
      # QUESTION: Or do we want make it so email is no longer a required attribute on User validation?
      def email
        'test@test.gov'
      end

      # NOTE: See comments for loa_current and loa_highest below
      # QUESTION: are the comments for deriving these loa levels sensible?
      # QUESTION: does F/E do any handling of LOA1 and LOA2 specifically or does it go by current / highest?
      # QUESTION: there should be minimal impact if we can get LOA2 to be the new rule for authorization vs LOA3
      # QUESTION: if LOA2 but no ICN, should it be treated as LOA1 with loa_highest = 3, requiring FICAM leveling?
      def loa
        { current: loa_current, highest: loa_highest }
      end

      # FIXME: For MHV users they may choose to opt in on 2FA at a later time.
      # QUESTION: We're going to need an attribute from ID.me that indicates current 2FA state as well.
      def two_fa
        # Probably belongs in `saml_response.settings` similar to `authn_context`
      end

      private

      # NOTE: email, uuid, loa are derived values, all others originate from MHV
      # For now we will probably not use available services, mhv profile is unnecessary
      # once we have the base components
      def serializable_attributes
        %i(mhv_icn account_type available_services email uuid loa)
      end

      # if the account type is premium then the user has identity proofed with MHV and we trust it
      def loa_current
        account_type == 'Premium' ? 2 : 1
      end

      # if the account type is premium there is no option to FICAM level up the account, so the highest is
      # the current level of 2. If however the user is Basic or Advanced, they should have the option
      # to level up their account using ID.me similar to other ID.me login users
      def loa_highest
        account_type == 'Premium' ? 2 : 3
      end
    end
  end
end
#:nocov:
