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
        'Eastern Region',
        'VA Regional Office',
        'P.O. Box 4616',
        'Buffalo, NY 14240-4616'
      ],
      southern: [
        'Southern Region',
        'VA Regional Office',
        'P.O. Box 100022',
        'Decatur, GA 30031-7022'
      ],
      central: [
        'Central Region',
        'VA Regional Office',
        'P.O. Box 66830',
        'St. Louis, MO 63166-6830'
      ],
      western: [
        'Western Region',
        'VA Regional Office',
        'P.O. Box 8888',
        'Muskogee, OK 74402-8888'
      ]
    }

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
      ADDRESSES[region_for(record)].join("\n")
    end
  end
end
