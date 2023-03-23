# frozen_string_literal: true

module Facilities
  class StateCemeteryReloadJob
    include Sidekiq::Worker

    def perform
      ActiveRecord::Base.transaction do
        purge_cemeteries
        fetch_cemeteries.xpath('//cems//cem').map do |cemetery|
          next if cemetery['lat'].blank? || cemetery['long'].blank?

          Facilities::NCAFacility.create build_attributes(cemetery)
        end
      end
    end

    private

    def purge_cemeteries
      Facilities::NCAFacility.where(classification: 'State Cemetery').delete_all
    end

    def fetch_cemeteries
      # our copy will become the source of truth but it is based off of:
      # Nokogiri::HTML(open("https://www.cem.va.gov/cems/cems.xml"))
      File.open(Rails.root.join('lib', 'facilities', 'cemetery_data', 'cems.xml')) do |file|
        Nokogiri::XML(file)
      end
    end

    def build_attributes(cemetery)
      { unique_id: "s#{cemetery['fac_id']}",
        name: cemetery['cem_name'],
        classification: 'State Cemetery',
        website: cemetery['cem_url'],
        lat: cemetery['lat'],
        long: cemetery['long'],
        address: {
          'physical' => parse_address(cemetery['address_line1'], cemetery['address_line2'], cemetery['address_line3']),
          'mailing' => parse_address(cemetery['mailing_line1'], cemetery['mailing_line2'], cemetery['mailing_line3'])
        },
        phone: {
          'main' => cemetery['phone'],
          'fax' => cemetery['fax']
        },
        hours:,
        services: {},
        feedback: {},
        access: {} }
    end

    def hours
      { 'Monday' => 'Sunrise - Sunset',
        'Tuesday' => 'Sunrise - Sunset',
        'Wednesday' => 'Sunrise - Sunset',
        'Thursday' => 'Sunrise - Sunset',
        'Friday' => 'Sunrise - Sunset',
        'Saturday' => 'Sunrise - Sunset',
        'Sunday' => 'Sunrise - Sunset' }
    end

    def parse_address(part1, part2, part3)
      return {} if part1.blank?

      if part2.blank?
        part1.match?(/, /) ? city_state_zip(part1) : { 'address_1' => part1 }
      elsif part3.blank?
        { 'address_1' => part1 }.merge(city_state_zip(part2))
      else
        { 'address_1' => part1, 'address_2' => part2 }.merge(city_state_zip(part3))
      end
    end

    def city_state_zip(part)
      city, state_zip = part.split(', ')
      state, zip = state_zip&.split
      { 'city' => city, 'state' => state, 'zip' => zip }
    end
  end
end
