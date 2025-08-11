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

        @claimant.power_of_attorney_holder.present? or
          return nil

        common_poa_holder =
          @representative.power_of_attorney_holders.find do |h|
            ##
            # Might be nice to instead have a `PowerOfAttorneyHolder#==` method
            # with a semantics that matches what is needed here.
            #
            h.poa_code == @claimant.power_of_attorney_holder.poa_code &&
              h.type == @claimant.power_of_attorney_holder.type
          end

        common_poa_holder.present? or
          return nil

        build(common_poa_holder)
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

    class Representative
      def initialize(icn:, email:, all_emails:)
        @icn = icn
        @email = email
        @all_emails = all_emails
      end

      delegate(
        :get_registration_number,
        :power_of_attorney_holders,
        to: :representative_user_account
      )

      private

      def representative_user_account
        @representative_user_account ||=
          RepresentativeUserAccount.find_by!(icn: @icn).tap do |account|
            account.set_email(@email)
            account.set_all_emails(@all_emails)
          end
      end
    end
  end
end
