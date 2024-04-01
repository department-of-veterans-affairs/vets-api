# frozen_string_literal: true

module Vye
  module BatchTransfer
    module EgressFiles
      BDN_TIMEZONE = 'Central Time (US & Canada)'

      extend self

      private

      def now_in_bdn_timezone
        Time.current.in_time_zone(BDN_TIMEZONE)
      end

      def prefixed_dated(prefix)
        "#{prefix}#{now_in_bdn_timezone.strftime('%Y%m%d%H%M%S')}.txt"
      end

      public

      # Change of addresses send to Newman every night.
      def address_changes_filename
        prefixed_dated 'CHGADD'
      end

      # Change of direct deposit send to Newman every night.
      def direct_deposit_filename
        prefixed_dated 'DirDep'
      end

      # Verification of no change in enrollment sent to BDN every night.
      # Some mainframes work with Julian dates. The BDN services expects this file
      # to have Julian dates as part of the filename.
      def no_change_enrollment_filename
        "vawave#{now_in_bdn_timezone.yday}"
      end
    end
  end
end
