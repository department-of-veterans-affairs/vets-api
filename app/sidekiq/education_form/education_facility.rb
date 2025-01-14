# frozen_string_literal: true

module EducationForm
  class EducationFacility
    # sourced from http://www.vba.va.gov/pubs/forms/VBA-22-1990-ARE.pdf

    EASTERN = %w[
      CO CT DE DC IA IL IN KS KY MA ME MI MD MN MO MT NC ND NE
      NH NJ NY OH PA RI SD TN VT VA WV WI WY VI AA
    ].freeze

    # We need to keep SOUTHERN and CENTRAL because existing records will have
    # this as a region, and we need to continue to show the counts
    # in the YTD reports.
    SOUTHERN = %w[].freeze
    CENTRAL = %w[].freeze

    WESTERN = %w[
      AK AL AR AZ CA FL GA HI ID LA MS NM NV OK OR SC TX UT WA
      GU PR AP
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
        '9770 Page Avenue',
        'Suite 101 Education',
        'St. Louis, MO 63132-1502'
      ],
      western: [
        'P.O. Box 8888',
        'Muskogee, OK 74402-8888'
      ]
    }.freeze

    REGIONS = ADDRESSES.keys

    RPO_NAMES = {
      eastern: 'BUFFALO (307)',
      southern: 'ATLANTA (316)',
      central: 'ST. LOUIS (331)',
      western: 'MUSKOGEE (351)'
    }.freeze

    EMAIL_NAMES = {
      eastern: 'Eastern Region',
      southern: 'Southern Region',
      central: 'Central Region',
      western: 'Western Region'
    }.freeze

    FACILITY_IDS = {
      eastern: 307,
      southern: 316,
      central: 331,
      western: 351
    }.freeze

    def self.facility_for(region:)
      FACILITY_IDS[region]
    end

    def self.rpo_name(region:)
      RPO_NAMES[region]
    end

    def self.region_for(model)
      record = model.open_struct_form
      address = routing_address(record, form_type: model.form_type)

      # special case 0993 and 1990s
      return :western if %w[0993 1990s].include?(model.form_type)

      # special case 0994
      # special case 10203
      return :eastern if %w[0994 10203].include?(model.form_type)

      # special case Philippines
      return :western if address&.country == 'PHL'

      check_area(address)
    end

    def self.check_area(address)
      area = address&.state
      if WESTERN.any? { |state| state == area }
        :western
      else
        :eastern
      end
    end

    def self.education_program(record)
      record.educationProgram || record.school
    end

    # Claims are sent to different RPOs based first on the location of the school
    # that the claim is relating to (either `school` or `newSchool` in our submissions)
    # or to the applicant's address (either as a relative or the veteran themselves)
    def self.routing_address(record, form_type:)
      case form_type.upcase
      when '1990'
        education_program(record)&.address || record.veteranAddress
      when '1990N'
        record.educationProgram&.address || record.veteranAddress
      when '1990E', '5490', '5495'
        record.educationProgram&.address || record.relativeAddress
      when '1995'
        record.newSchool&.address || record.veteranAddress
      end
    end

    def self.regional_office_for(model)
      region = region_for(model)
      ['VA Regional Office', ADDRESSES[region]].join("\n")
    end
  end
end
