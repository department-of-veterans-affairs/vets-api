# frozen_string_literal: true

module Vye
  module BatchTransfer
    module EgressFiles
      BDN_TIMEZONE = 'Central Time (US & Canada)'

      private_constant :BDN_TIMEZONE

      include Vye::CloudTransfer

      extend self

      private

      def now_in_bdn_timezone = Time.current.in_time_zone(BDN_TIMEZONE)

      def prefixed_dated(prefix) = "#{prefix}#{now_in_bdn_timezone.strftime('%Y%m%d%H%M%S')}.txt"

      # Change of addresses send to Newman everyday.
      def address_changes_filename = prefixed_dated('CHGADD')

      # Change of direct deposit send to Newman everyday.
      def direct_deposit_filename = prefixed_dated('DirDep')

      # enrollment verification sent to BDN everyday.
      def verification_filename = format('vawave%03d', now_in_bdn_timezone.yday)

      public

      def address_changes_upload
        upload_report(address_changes_filename, &AddressChange.method(:write_report))
      end

      def direct_deposit_upload
        upload_report(direct_deposit_filename, &DirectDepositChange.method(:write_report))
      end

      def verification_upload
        upload_report(verification_filename, &Verification.method(:write_report))
      end
    end
  end
end
