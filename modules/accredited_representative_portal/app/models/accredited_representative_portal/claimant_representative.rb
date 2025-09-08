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
      def find(...)
        Finder.new(...).perform
      end
    end

    class Finder
      Error = Class.new(RuntimeError)

      def initialize(claimant_icn:, power_of_attorney_holder_memberships:)
        @claimant =
          Claimant.new(icn: claimant_icn)

        @power_of_attorney_holder_memberships =
          power_of_attorney_holder_memberships
      end

      def perform
        @claimant.power_of_attorney_holder.present? or
          return nil

        membership =
          @power_of_attorney_holder_memberships.for_power_of_attorney_holder(
            @claimant.power_of_attorney_holder
          )

        membership.present? or
          return nil

        build(membership)
      rescue
        raise Error
      end

      private

      def build(membership)
        holder =
          membership.power_of_attorney_holder

        ClaimantRepresentative.new(
          claimant_id: @claimant.id,
          power_of_attorney_holder_type: holder.type,
          power_of_attorney_holder_poa_code: holder.poa_code,
          accredited_individual_registration_number:
            membership.registration_number
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
        defined?(@power_of_attorney_holder) and
          return @power_of_attorney_holder

        @power_of_attorney_holder =
          begin
            service = BenefitsClaims::Service.new(identifier.icn)
            response = service.get_power_of_attorney['data'].to_h

            type =
              case response['type']
              when 'organization'
                PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION

              ##
              # Lighthouse API does not currently distinguish between claims
              # agents and attorneys like we do internally.
              #
              when 'individual'
                'individual'
              end

            ##
            # For now we'll build an incomplete `PowerOfAttorneyHolder` object
            # for the claimant from the API response:
            # - Unknown `can_accept_digital_poa_requests`
            # - Undifferentiated `individual` type
            #
            # Call sites are fine with this currently.
            #
            type.presence &&
              PowerOfAttorneyHolder.new(
                type:, poa_code: response.dig('attributes', 'code'),
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
  end
end
