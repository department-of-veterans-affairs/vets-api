# frozen_string_literal: true

require 'faraday'
require 'vcr'
require Rails.root.join('spec/support/vcr')

module Common
  module Client
    module Middleware
      class Mock < Faraday::Middleware
        def initialize(app, options = {})
          super(app)
          @cassette_dir = options[:cassette_dir]
          @record_mode = options[:record] || :none
        end

        def call(env)
          return @app.call(env) unless Settings.vsp_environment != 'production'

          cassette_name = find_matching_cassette(env)
          puts "Mock using VCR cassette: #{cassette_name}"

          VCR.use_cassette(cassette_name, record: @record_mode, match_requests_on: [:method, :uri]) do
            @app.call(env)
          end
        end

        private

        def find_matching_cassette(env)
          request_uri = env.url.to_s

          Dir.glob("spec/support/vcr_cassettes/#{@cassette_dir}/*.yml").each do |file|
            yaml_data = YAML.load_file(file)
            interactions = yaml_data['http_interactions']

            next unless interactions

            interactions.each do |interaction|

              request_match = interaction.dig('request', 'uri').gsub(/<.*?>/, '') == URI(request_uri).path
              ok_response = interaction.dig('response','status','code') == 200

              if request_match && ok_response
                return file.gsub("spec/support/vcr_cassettes/", '').gsub('.yml', '')
              end
            end
          end

          nil
        end
      end
    end
  end
end

=begin

Usage

Mock using VCR cassette: va_profile/v2/contact_information/person
 =>
#<VAProfile::V2::ContactInformation::PersonResponse:0x0000000300e1b9e8
 @errors_hash={},
 @metadata={},
 @original_attributes=
  {:status=>nil,
   :person=>
    #<VAProfile::Models::V3::Person:0x0000000300e54b08
     @addresses=
      [#<VAProfile::Models::V3::Address:0x00000003006d5878
        @address_line1="1495 Martin Luther King Rd",
        @address_line2=nil,
        @address_line3=nil,
        @address_pou="RESIDENCE",
        @address_type="DOMESTIC",

=end
