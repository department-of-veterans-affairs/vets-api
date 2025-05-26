# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantRepresentative <
    Data.define(
      :claimant_id,
      :power_of_attorney_holder_type,
      :power_of_attorney_holder_poa_code,
      :accredited_individual_registration_number
    )

    class << self
      def find(&)
        Finder.new.tap(&).perform
      end
    end

    class Finder
      Error = Class.new(RuntimeError)

      def perform
        unless [@claimant, @representative].all?(&:present?)
          raise ArgumentError, <<~MSG.squish
            all of `claimant' and `representative'
            must be present
          MSG
        end

        poa_holder = @claimant.power_of_attorney_holder
        poa_holders = @representative.power_of_attorney_holders

        poa_holders.each do |h|
          ##
          # Would be nice to be able to use `PowerOfAttorneyHolder#==` instead.
          #
          next unless h.poa_code == poa_holder.poa_code
          next unless h.type == poa_holder.type

          return build(h)
        end

        nil
      rescue
        raise Error
      end

      def for_claimant(...)
        @claimant = Claimant.new(...)
      end

      def for_representative(...)
        @representative = Representative.new(...)
      end

      private

      def build(poa_holder)
        ClaimantRepresentative.new(
          claimant_id: @claimant.id,
          power_of_attorney_holder_type: poa_holder.type,
          power_of_attorney_holder_poa_code: poa_holder.poa_code,
          accredited_individual_registration_number:
            @representative.get_registration_number(
              poa_holder.type
            )
        )
      end
    end

    class Claimant
      def initialize(id: nil, icn: nil)
        unless [id, icn].one?(&:present?)
          raise ArgumentError, <<~MSG.squish
            exactly one of `id' or `icn'
            must be present
          MSG
        end

        @id = id
        @icn = icn
      end

      delegate :id, to: :identifier

      def power_of_attorney_holder
        @power_of_attorney_holder ||= begin
          service = BenefitsClaims::Service.new(identifier.icn)
          response = service.get_power_of_attorney['data']

          ##
          # Also, the API does not fully distinguish types like we do. The value
          # 'individual' is returned for both claims agents and attorneys.
          #
          response['type'] == 'organization' or
            raise 'Unsupported power of attorney holder type'

          PowerOfAttorneyHolder.new(
            type: PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION,
            poa_code: response.dig('attributes', 'code'),
            can_accept_digital_poa_requests: nil
          )
        end
      end

      private

      def identifier
        @identifier ||=
          if @icn.present?
            IcnTemporaryIdentifier.find_or_create_by(icn: @icn)
          else
            IcnTemporaryIdentifier.find(@id)
          end
      end
    end

    class Representative
      def initialize(icn:, email:)
        @icn = icn
        @email = email
      end

      delegate(
        :get_registration_number,
        to: :representative_user_account
      )

      def power_of_attorney_holders
        ##
        # TODO: Make this method public once the codebase is churning less.
        #
        representative_user_account.send(
          :power_of_attorney_holders
        )
      end

      private

      def representative_user_account
        @representative_user_account ||=
          RepresentativeUserAccount.find_by!(icn: @icn).tap do |account|
            account.set_email(@email)
          end
      end
    end
  end
end
