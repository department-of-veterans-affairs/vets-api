# frozen_string_literal: true
require "uri"
require "cgi"

module Lighthouse
  module HCC
    class Bundle
      include Vets::Model

      # declare if you want them exposed to serializers, but we'll just set ivars
      attribute :entries, Array
      attribute :links, Hash
      attribute :meta, Hash
      attribute :total, Integer
      attribute :page, Integer
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
        rels = (@bundle['link']).index_by { |l| l['relation'] }
        links = {
          self:  rels['self']&.dig('url'),
          first: rels['first']&.dig('url'),
          prev:  (rels['previous'] || rels['prev'])&.dig('url'),
          next:  rels['next']&.dig('url'),
          last:  rels['last']&.dig('url')
        }.compact

        return links unless @link_builder # keep LH links if no builder provided

        # Rewrite to YOUR API using page + size from each LH link
        links.transform_values do |lh_url|
          qs   = CGI.parse(URI(lh_url).query.to_s)
          page = (qs['page']&.first || 1).to_i
          size = (qs['_count']&.first || @per_page || 50).to_i
          @link_builder.call(page, size)
        end
      end

      def build_meta
        self_url = @links[:self]
        query_string = self_url ? CGI.parse(URI(self_url).query.to_s) : {}

        {
          total: (@bundle['total'] || 0).to_i,
          page: (query_string['page']&.first).to_i,
          per_page: (query_string['_count']&.first).to_i
        }
      end
    end
  end
end
