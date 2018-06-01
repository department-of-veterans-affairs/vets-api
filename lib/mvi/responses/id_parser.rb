# frozen_string_literal: true

module MVI
  module Responses
    class IdParser
      CORRELATION_ROOT_ID = '2.16.840.1.113883.4.349'
      EDIPI_ROOT_ID = '2.16.840.1.113883.3.42.10001.100001.12'
      ICN_REGEX = /^\w+\^NI\^\w+\^\w+\^\w+$/
      VET360_ASSIGNING_AUTHORITY_ID = '^NI^200M^USVHA^P'

      # MVI correlation id source id relationships:
      # {source id}^{id type}^{assigning facility}^{assigning authority}^{id status}
      # NI = national identifier, PI = patient identifier
      def parse(ids)
        ids = ids.map(&:attributes)

        {
          icn: select_ids(select_extension(ids, ICN_REGEX, CORRELATION_ROOT_ID))&.first,
          sec_id: select_ids(select_extension(ids, /^\w+\^PN\^200PROV\^USDVA\^\w+$/, CORRELATION_ROOT_ID))&.first,
          mhv_ids: select_ids(select_extension(ids, /^\w+\^PI\^200MH.{0,1}\^\w+\^\w+$/, CORRELATION_ROOT_ID)),
          active_mhv_ids: select_ids(select_extension(ids, /^\w+\^PI\^200MH.{0,1}\^\w+\^A$/, CORRELATION_ROOT_ID)),
          edipi: select_ids(select_extension(ids, /^\w+\^NI\^200DOD\^USDOD\^\w+$/, EDIPI_ROOT_ID))&.first,
          vba_corp_id: select_ids(select_extension(ids, /^\w+\^PI\^200CORP\^USVBA\^\w+$/, CORRELATION_ROOT_ID))&.first,
          vha_facility_ids: select_facilities(select_extension(ids, /^\w+\^PI\^\w+\^USVHA\^\w+$/, CORRELATION_ROOT_ID)),
          birls_id: select_ids(select_extension(ids, /^\w+\^PI\^200BRLS\^USVBA\^\w+$/, CORRELATION_ROOT_ID))&.first,
          vet360_id: select_ids(select_extension(ids, /^\w+\^PI\^200VETS\^USDVA\^\w+$/, CORRELATION_ROOT_ID))&.first
        }
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
    end
  end
end
