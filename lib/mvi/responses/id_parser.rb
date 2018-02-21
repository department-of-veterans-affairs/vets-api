# frozen_string_literal: true

module MVI
  module Responses
    class IdParser
      include SentryLogging
      CORRELATION_ROOT_ID = '2.16.840.1.113883.4.349'
      EDIPI_ROOT_ID = '2.16.840.1.113883.3.42.10001.100001.12'

      # MVI correlation id source id relationships:
      # {source id}^{id type}^{assigning facility}^{assigning authority}^{id status}
      # NI = national identifier, PI = patient identifier
      def parse(ids)
        ids = ids.map(&:attributes)
        binding.pry; fail
        icns = select_ids(select_extension(ids, /^\w+\^NI\^\w+\^\w+\^\w+$/, CORRELATION_ROOT_ID))

        {
          icn: icns&.first,
          sec_id: select_ids(select_extension(ids, /^\w+\^PN\^200PROV\^USDVA\^\w+$/, CORRELATION_ROOT_ID))&.first,
          mhv_ids: select_ids(select_extension(ids, /^\w+\^PI\^200MH.{0,1}\^\w+\^\w+$/, CORRELATION_ROOT_ID)),
          active_mhv_ids: select_ids(select_extension(ids, /^\w+\^PI\^200MH.{0,1}\^\w+\^A$/, CORRELATION_ROOT_ID)),
          edipi: select_ids(select_extension(ids, /^\w+\^NI\^200DOD\^USDOD\^\w+$/, EDIPI_ROOT_ID))&.first,
          vba_corp_id: select_ids(select_extension(ids, /^\w+\^PI\^200CORP\^USVBA\^\w+$/, CORRELATION_ROOT_ID))&.first,
          historical_icns: get_historical_icns(icns),
          vha_facility_ids: select_facilities(select_extension(ids, /^\w+\^PI\^\w+\^USVHA\^\w+$/, CORRELATION_ROOT_ID)),
          birls_id: select_ids(select_extension(ids, /^\w+\^PI\^200BRLS\^USVBA\^\w+$/, CORRELATION_ROOT_ID))&.first
        }
      end

      private

      def get_historical_icns(icns)
        return_val = icns.select.with_index { |_, i| i.positive? }

        if return_val.present?
          log_message_to_sentry(
            'historical icns',
            :info,
            {
              icns: return_val
            },
            backend_service: :mvi
          )
        end

        return_val
      end

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
