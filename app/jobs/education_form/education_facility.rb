# frozen_string_literal: true
module EducationForm
  class EducationFacility
    # sourced from http://www.vba.va.gov/pubs/forms/VBA-22-1990-ARE.pdf

    DEFAULT = :eastern

    EASTERN = %w(
      CT DE DC ME MD MA NH NJ NY PA
      RI VT VA
    ).freeze

    SOUTHERN = [
      'GA', 'NC', 'PR', 'US Virgin Islands', 'APO/FPO AA'
    ].freeze

    CENTRAL = %w(
      CO IA IL IN KS KY MI MN MO MT
      NE ND OH SD TN WV WI WY
    ).freeze

    WESTERN = [
      'AK', ' AL', 'AR', 'AZ', 'CA', 'FL', 'HI', 'ID', 'LA', 'MS',
      'NM', 'NV', 'OK', 'OR', 'SC', 'TX', 'UT', 'WA', 'Philippines',
      'Guam', 'APO/FPO AP'
    ].freeze

    ADDRESSES = {
      eastern: [
        'P.O. Box 4616',
        'Buffalo, NY 14240-4616'
      ],
      southern: [
        'P.O. Box 100022',
        'Decatur, GA 30031-7022'
      ],
      central: [
        'P.O. Box 66830',
        'St. Louis, MO 63166-6830'
      ],
      western: [
        'P.O. Box 8888',
        'Muskogee, OK 74402-8888'
      ]
    }.freeze

    REGIONS = ADDRESSES.keys

    def self.region_for(record)
      area = record.school&.address&.state || record.veteranAddress&.state
      case area
      when *EASTERN
        :eastern
      when *SOUTHERN
        :southern
      when *CENTRAL
        :central
      when *WESTERN
        :western
      else
        DEFAULT
      end
    end

    def self.regional_office_for(record)
      region = region_for(record)
      address = ["#{region.to_s.capitalize} Region", 'VA Regional Office']
      address += ADDRESSES[region]
      address.join("\n")
    end
  end
end
