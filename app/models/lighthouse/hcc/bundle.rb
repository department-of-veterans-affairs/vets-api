# frozen_string_literal: true

module Lighthouse
  module HCC
    class Bundle
      include Vets::Model

      attribute :entries,  Array
      attribute :links,    Hash
      attribute :meta,     Hash
      attribute :total,    Integer
      attribute :page,     Integer
      attribute :per_page, Integer

      def initialize(bundle_hash, entries)
        @bundle = bundle_hash
        @entries = entries
        @links = build_links
        @meta = build_meta
        @total = @meta[:total]
        @page = @meta[:page]
        @per_page = @meta[:per_page]
      end

      private

      def build_links
        raw_links = @bundle['link']
        return {} if raw_links.empty?

        relations = raw_links.index_by { |l| l['relation'] }

        lh_links = {
          self: relations['self']&.dig('url'),
          first: relations['first']&.dig('url'),
          prev: (relations['previous'] || relations['prev'])&.dig('url'),
          next: relations['next']&.dig('url'),
          last: relations['last']&.dig('url')
        }.compact

        lh_links.transform_values { |u| rewrite_to_vets_api(u) }.compact
      end

      def rewrite_to_vets_api(lh_url)
        uri = URI(lh_url)
        base = URI(api_base_uri)

        uri.scheme = base.scheme
        uri.host = base.host
        uri.port = base.port

        if uri.query.present?
          params = CGI.parse(uri.query)
          params.delete('patient')
          uri.query = params.any? ? URI.encode_www_form(params) : nil
        end

        uri.to_s
      end

      def api_base_uri
        "#{Rails.application.config.protocol}://#{Rails.application.config.hostname}"
      end

      def build_meta
        relations = @bundle['link'].to_a.index_by { |l| l['relation'] }
        self_url = relations['self']&.dig('url')

        base_meta = {
          total: @bundle['total'].to_i,
          page: nil,
          per_page: nil
        }

        return base_meta.merge(copay_summary_meta) if self_url.blank?

        query_string = CGI.parse(URI(self_url).query.to_s)

        {
          total: @bundle['total'].to_i,
          page: query_string['page']&.first.to_i,
          per_page: query_string['_count']&.first.to_i
        }.merge(copay_summary_meta)
      end

      def copay_summary_meta
        total_current_balance = @entries.reduce(BigDecimal('0')) do |sum, entry|
          sum + BigDecimal(entry.current_balance.to_s)
        end
        copay_bill_count = @entries.size
        last_updated_on = @entries.maximum(:last_updated_at)

        {
          copay_summary: {
            total_current_balance: total_current_balance.to_f,
            copay_bill_count:,
            last_updated_on:
          }
        }
      end
    end
  end
end
