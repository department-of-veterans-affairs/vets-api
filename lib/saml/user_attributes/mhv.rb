# frozen_string_literal: true
require 'saml/user_attributes/base_decorator'

module SAML
  module UserAttributes
    class MHV < BaseDecorator
      PREMIUM_LOAS = %w(Premium).freeze
      MVI_ATTRIBUTES = %i(given_names family_name birth_date ssn gender).freeze
      BasicLOA3User = Struct.new('BasicUser', :uuid, :mhv_icn) do
        def loa3?
          true
        end
      end
      NullMvi = Struct.new('NullMvi', *MVI_ATTRIBUTES) do
        def profile
          self
        end
      end

      def mhv_icn
        attributes['mhv_icn']
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

      # NOTE: this is the same thing as mhv_correlation_id it should supercede any mhv
      # mhv correlation id that is returned by MVI
      def mhv_correlation_id
        attributes['mhv_uuid']
      end

      def uuid
        attributes['uuid']
      end

      # NOTE: This attribute is originated by id.me
      def email
        attributes['email']
      end

      # NOTE: This attribute is originated by id.me
      def multifactor
        attributes['multifactor']
      end

      # NOTE: See comments for loa_current and loa_highest below
      def loa
        { current: loa_current, highest: loa_highest }
      end

      # NOTE: email, uuid, loa are derived values, all others originate from MHV
      # For now we will probably not use available services, mhv profile is unnecessary
      # once we have the base components. But we do need to sideload from MVI the attributes if LOA3
      def serializable_attributes
        %i(mhv_icn email uuid loa multifactor) + %i(first_name middle_name last_name birth_date ssn gender)
      end

      # NOTE: this will always be a JSON object, see above
      def mhv_profile
        JSON.parse(attributes['mhv_profile'])
      end

      def idme_loa
        attributes['level_of_assurance']&.to_i
      end

      # if the account_type PREMIUM, otherwise 1
      # NOTE: idme will always return highest attained, but for iniital non-premium this will always be 1
      # the leveling up verification step invoked by F/E will correctly capture as LOA3.
      def loa_current
        PREMIUM_LOAS.include?(account_type) ? 3 : 1
      end

      # This is "highest attained" via idp
      # if the account_type PREMIUM or IDME = 3,
      def loa_highest
        PREMIUM_LOAS.include?(account_type) ? 3 : (idme_loa || loa_current)
      end

      # Attributes from MVI
      def first_name
        mvi&.profile&.given_names&.first
      end

      def middle_name
        mvi&.profile&.given_names&.last
      end

      def last_name
        mvi&.profile&.family_name
      end

      def birth_date
        mvi&.profile&.birth_date
      end

      def ssn
        mvi&.profile&.ssn
      end

      def gender
        mvi&.profile&.gender
      end

      # Probably need to rescue from when ICN query returns no result returning NullMVI
      # Logging these various scenarios would provide useful data
      def mvi
        @mvi ||= begin
          if PREMIUM_LOAS.include?(account_type)
            if mhv_icn.present?
              # What if the ICN doesn't return a hit when querying MVI???
              # Null values for any of the loa3_user validations will result in error when persisting.
              Mvi.for_user(BasicLOA3User.new(uuid, mhv_icn))
            else
              # either have to treat this as LOA1 or???
              # Null values for any of the loa3_user validations will result in error when persisting.
              NullMvi.new
            end
          else
            NullMvi.new
          end
        end
      end
    end
  end
end
