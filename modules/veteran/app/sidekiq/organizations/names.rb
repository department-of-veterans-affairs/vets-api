# frozen_string_literal: true

require 'vets/shared_logging'

module Organizations
  class Names
    ORGS = [
      { poa: '80', name: 'Blinded Veterans Association' },
      { poa: '85', name: 'Fleet Reserve Association' },
      { poa: '91', name: 'African American PTSD Association' },
      { poa: '65', name: '--- A-X-P-O-W- *no longer recognized*' },
      { poa: '74', name: 'American Legion' },
      { poa: '75', name: 'American Red Cross' },
      { poa: '77', name: 'American Veterans' },
      { poa: '78', name: 'Armed Forces Services Corporation' },
      { poa: '79', name: 'Army and Navy Union, USA' },
      { poa: '81', name: 'Catholic War Veterans of the USA' },
      { poa: '83', name: 'Disabled American Veterans' },
      { poa: '12', name: 'Gold Star Wives of America, Inc.' },
      { poa: '95', name: 'Italian American War Veterans of the US, Inc.' },
      { poa: '86', name: 'Jewish War Veterans of the USA' },
      { poa: '87', name: 'Legion of Valor of the USA, Inc.' },
      { poa: '88', name: 'Marine Corps League' },
      { poa: '24', name: '--- N-A-F-     *no longer recognized*' },
      { poa: '84', name: 'National Association for Black Veterans, Inc.' },
      { poa: '64', name: 'National Association of County Veterans Service Officers' },
      { poa: '82', name: 'National Veterans Legal Services Program' },
      { poa: '93', name: 'Navy Mutual Aid Association' },
      { poa: '62', name: '--- N-C-O-A-   *no longer recognized*' },
      { poa: '71', name: 'Paralyzed Veterans of America' },
      { poa: '3', name: 'Polish Legion of American Veterans' },
      { poa: '43', name: 'Swords to Plowshares' },
      { poa: '7', name: 'The Retired Enlisted Association' },
      { poa: '96', name: 'United Spanish War Veterans * NOT ACCEPTING NEW CLAIMS *' },
      { poa: '90', name: 'United Spinal Association' },
      { poa: '63', name: '--- V-A-F-     *no longer recognized*' },
      { poa: '97', name: 'Veterans of Foreign Wars' },
      { poa: '4R4', name: 'Veterans of the Vietnam War, Inc. & the Veterans Coalition' },
      { poa: '98', name: 'Veterans of WW I of the USA, Inc.* NOT ACCEPTING NEW CLAIMS *' },
      { poa: '29', name: '--- V-E-V-A-   *no longer recognized*' },
      { poa: '70', name: 'Vietnam Veterans of America' },
      { poa: '22', name: 'Alabama Department of Veterans Affairs' },
      { poa: '50', name: 'Arkansas Department of Veterans Affairs' },
      { poa: '44', name: 'California Department of Veterans Services' },
      { poa: '39', name: 'Colorado Division of Veterans Affairs' },
      { poa: '4R1', name: 'Commonwealth of the Northern Mariana Islands Division' },
      { poa: '60', name: 'Delaware Commission of Veterans Affairs' },
      { poa: '16', name: 'Georgia Department of Veterans Service' },
      { poa: '59', name: 'Hawaii Office of Veterans Services' },
      { poa: '47', name: 'Idaho Division of Veterans Services' },
      { poa: '28', name: 'Illinois Department of Veterans Affairs' },
      { poa: '52', name: "Kansas Commission on Veterans' Affairs" },
      { poa: '27', name: 'Kentucky Department of Veterans Affairs' },
      { poa: '21', name: 'Louisiana Department of Veterans Affairs' },
      { poa: '2', name: "Maine Veterans' Services" },
      { poa: '4R0', name: 'Maryland Department of Veterans Affairs' },
      { poa: '4R3', name: "Massachusetts Department of Veterans' Services" },
      { poa: '35', name: 'Minnesota Department of Veterans Affairs' },
      { poa: '23', name: 'Mississippi Veterans Affairs' },
      { poa: '31', name: 'Missouri Veterans Commission' },
      { poa: '54', name: 'Nevada Department of Veterans Services' },
      { poa: '73', name: 'New Hampshire Division of Veteran Services' },
      { poa: '9', name: 'New Jersey Department of Military and Veterans Affairs' },
      { poa: '6', name: "New York State Department of Veterans' Services" },
      { poa: '18', name: 'North Carolina Dept Military and Veterans Affairs' },
      { poa: '37', name: 'North Dakota Department Veterans Affairs' },
      { poa: '25', name: 'Ohio Department of Veterans Services' },
      { poa: '51', name: 'Oklahoma Department of Veterans Affairs' },
      { poa: '48', name: 'Oregon Department of Veterans Affairs' },
      { poa: '10', name: 'Pennsylvania Department of Military and Veterans Affairs' },
      { poa: '4', name: 'Rhode Island Office of Veterans Services (RIVETS)' },
      { poa: '19', name: 'The South Carolina Department of Veterans Affairs' },
      { poa: '38', name: 'South Dakota Department of Veterans Affairs' },
      { poa: '49', name: 'Texas Veterans Commission' },
      { poa: '41', name: 'Utah Department of Veterans and Military Affairs' },
      { poa: '32', name: 'Virgin Islands Office of Veterans Affairs' },
      { poa: '14', name: 'Virginia Department of Veterans Services' },
      { poa: '46', name: 'Washington Department of Veterans Affairs' },
      { poa: '15', name: 'West Virginia Dept of Veterans Assistance' },
      { poa: '30', name: 'Wisconsin Department of Veterans Affairs' },
      { poa: '56', name: 'Guam Office of Veterans Affairs' },
      { poa: '17', name: 'Florida Department of Veterans Affairs' },
      { poa: '68', name: '--- Am.GI Forum -  * NOT ACCEPTING NEW CLAIMS *' },
      { poa: '00V', name: 'Wounded Warrior Project' },
      { poa: '100', name: '--- A-V-V-A-   *no longer recognized*' },
      { poa: '89', name: '--- M-O-P-H-   *no longer recognized*' },
      { poa: '94', name: 'National Veterans Organization of America' },
      { poa: '20', name: 'Tennessee Department of Veterans Services' },
      { poa: '34', name: 'Nebraska Department of Veterans Affairs' },
      { poa: '869', name: 'Wyoming Veterans Commission' },
      { poa: '8FE', name: 'Michigan Veterans Affairs Agency' },
      { poa: 'A2I', name: 'Military Officers Association of America' },
      { poa: 'ABA', name: 'American Bar Association' },
      { poa: 'E5L', name: 'Indiana Department of Veterans Affairs' },
      { poa: '5', name: 'Vermont Office of Veterans Affairs' },
      { poa: '45', name: 'Arizona Department of Veterans Services' },
      { poa: 'FYT', name: 'National Law School Veterans Clinic Consortium' },
      { poa: '33', name: 'Iowa Department of Veterans Affairs' },
      { poa: '8', name: 'Connecticut Department of Veterans Affairs' },
      { poa: '40', name: 'New Mexico Department of Veterans Services' },
      { poa: '55', name: 'Puerto Rico Veterans Advocate Office' },
      { poa: '4R2', name: 'Office of Veterans Affairs American Samoa Government' },
      { poa: 'HTC', name: 'Green Beret Foundation' },
      { poa: 'HW0', name: 'Dale K. Graham Veterans Foundation' },
      { poa: 'IP4', name: 'Navajo Nation Veterans Administration' },
      { poa: 'J3C', name: "Veterans' Voice of America" },
      { poa: 'JCV', name: 'Gila River Indian Community Vet.&Fam. Svcs Office' },
      { poa: '36', name: 'Montana Veterans Affairs (MVAD)' }
    ].freeze

    def self.orgs_data
      ORGS
    end

    def self.all
      orgs_data.map do |org|
        serialized_poa = serialize_poa(org[:poa])
        { poa: serialized_poa, name: org[:name] }
      rescue => e
        # Since the deprecated Vets::SharedLogging was designed for instance methods, not class methods,
        # and we need to invoke these methods within a class method context, we instantiate a dummy_logger.
        # This dummy object previously included Vets::SharedLogging (now uses Vets::SharedLogging), allowing us to
        # use its logging capabilities without altering the original module's design. This approach enables
        # class-level logging by leveraging the module's instance methods, ensuring we can log messages to
        # Sentry from static (class) contexts while maintaining the module's intended usage patterns.
        dummy_logger = Class.new { include Vets::SharedLogging }.new
        dummy_logger.log_message_to_sentry("Failed to serialize POA in Organizations::Names: #{e.message}. POA: '#{org[:poa]}', Org Name: '#{org[:name]}'.", 'error') # rubocop:disable Layout/LineLength
        next
      end.compact
    end

    def self.serialize_poa(poa)
      case poa.length
      when 3
        poa
      when 2
        "0#{poa}"
      when 1
        "00#{poa}"
      else
        raise StandardError, "Invalid POA format: #{poa}"
      end
    end
  end
end
