# frozen_string_literal: true

module Preneeds
  module Middleware
    module Response
      # Faraday middleware responsible for customizing parsing of the EOAS response.
      #
      class PreneedsParser < Faraday::Middleware
        # Parses the EOAS response.
        #
        # @return [Faraday::Env]
        #
        def on_complete(env)
          return unless env.response_headers['content-type']&.match?(/\bxml/)

          env[:body] = parse(env.body) if env.body.present?
        end

        private

        def parse(body)
          hash = Hash.from_xml(Ox.dump(body))&.deep_transform_keys(&:underscore)
          hash = extract_soap_body(hash)

          key = hash&.keys&.first
          if key.present?
            hash = hash[key]['return']
            hash = map_military_rank_id_to_details(hash) if key == 'get_military_rank_for_branch_of_service_response'
          end

          { data: hash }
        end

        def extract_soap_body(hash)
          hash = hash['envelope'] if hash.keys.include?('envelope')
          hash = hash['body'] if hash.keys.include?('body')

          hash
        end

        def map_military_rank_id_to_details(hash)
          hash.map do |rank|
            rank['military_rank_detail'] = rank.delete('id')
            rank
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware preneeds_parser: Preneeds::Middleware::Response::PreneedsParser
