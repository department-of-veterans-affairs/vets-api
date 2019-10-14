# frozen_string_literal: true

module MVI
  module Responses
    class IdParser
      CORRELATION_ROOT_ID = '2.16.840.1.113883.4.349'
      EDIPI_ROOT_ID = '2.16.840.1.113883.3.42.10001.100001.12'
      ICN_REGEX = /^\w+\^NI\^200M\^USVHA\^\w+$/.freeze
      PERMANENT_ICN_REGEX = /^\w+\^NI\^200M\^USVHA\^P$/.freeze
      VET360_ASSIGNING_AUTHORITY_ID = '^NI^200M^USVHA'

      # MVI correlation id source id relationships:
      # {source id}^{id type}^{assigning facility}^{assigning authority}^{id status}
      # id type - NI = national identifier
      #           PI = patient identifier
      #           EI - employee identifier
      #           PN = patient number

      # id status -  A = Active (only applies to correlation IDs)
      #              P = Permanent (only applies to ICNs)

      # Should definitely NOT be using id_status
      #              H = Deprecated due to local merge
      #              D = Deprecated from a Duplicate
      #              M = Deprecated from a Mismatch
      #              U - Deprecated from an Unlink
      #              L = pending local merge - This is a value identified for correlations including EDIPI when the
      #                   identifier has been deprecated/associated to another active ID.
      #              PCE = Pending Cat Edit correlations (unsure if this should be used, likely not)

      def parse(ids)
        ids = ids.map(&:attributes)
        # rubocop:disable LineLength
        {
          icn:              select_ids(select_extension(ids, PERMANENT_ICN_REGEX,               CORRELATION_ROOT_ID))&.first,
          sec_id:           select_ids(select_extension(ids, /^\w+\^PN\^200PROV\^USDVA\^A$/,    CORRELATION_ROOT_ID))&.first,
          mhv_ids:          select_ids(select_extension(ids, /^\w+\^PI\^200MH.{0,1}\^\w+\^\w+$/,  CORRELATION_ROOT_ID)),
          active_mhv_ids:   select_ids(select_extension(ids, /^\w+\^PI\^200MH.{0,1}\^\w+\^A$/,    CORRELATION_ROOT_ID)),
          edipi:            select_ids(select_extension(ids, /^\w+\^NI\^200DOD\^USDOD\^A$/,     EDIPI_ROOT_ID))&.first,
          vba_corp_id:      select_ids(select_extension(ids, /^\w+\^PI\^200CORP\^USVBA\^A$/,  CORRELATION_ROOT_ID))&.first,
          vha_facility_ids: select_facilities(select_extension(ids, /^\w+\^PI\^\w+\^USVHA\^\w+$/, CORRELATION_ROOT_ID)),
          birls_id:         select_ids(select_extension(ids, /^\w+\^PI\^200BRLS\^USVBA\^A$/,    CORRELATION_ROOT_ID))&.first,
          vet360_id:        select_ids(select_extension(ids, /^\w+\^PI\^200VETS\^USDVA\^A$/,      CORRELATION_ROOT_ID))&.first,
          icn_with_aaid: ICNWithAAIDParser.new(full_icn_with_aaid(ids)).without_id_status
        }
        # rubocop:enable LineLength
      end

      def select_ids_with_extension(ids, pattern, root)
        select_ids(select_extension(ids, pattern, root))
      end

      private

      def select_ids(extensions)
        return nil if extensions.empty?

        extensions.map { |e| e[:extension].split('^')&.first }
      end

      def select_facilities(extensions)
        return nil if extensions.empty?

        extensions.map { |e| e[:extension].split('^')&.third }
      end

      def select_extension(ids, pattern, root)
        ids.select do |id|
          id[:extension] =~ pattern && id[:root] == root
        end
      end

      def full_icn_with_aaid(ids)
        select_extension(ids, PERMANENT_ICN_REGEX, CORRELATION_ROOT_ID)&.first&.dig(:extension)
      end
    end
  end
end
