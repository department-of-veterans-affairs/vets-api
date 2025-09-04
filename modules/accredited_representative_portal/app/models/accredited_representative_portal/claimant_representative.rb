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

        common_membership =
          @power_of_attorney_holder_memberships.load.find do |membership|
            ##
            # Might be nice to instead have a `PowerOfAttorneyHolder#==` method
            # with a semantics that matches what is needed here.
            #
            holder = membership.power_of_attorney_holder
            holder.poa_code == @claimant.power_of_attorney_holder.poa_code &&
              holder.type == @claimant.power_of_attorney_holder.type
          end

        common_membership.present? or
          return nil

        build(common_membership)
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

            ##
            # FYI, the API does not fully distinguish types like we do.
            # The value 'individual' is returned for both claims agents and
            # attorneys.
            #
            if response['type'] == 'organization'
              PowerOfAttorneyHolder.new(
                type: PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION,
                poa_code: response.dig('attributes', 'code'),
                can_accept_digital_poa_requests: nil
              )
            end
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
