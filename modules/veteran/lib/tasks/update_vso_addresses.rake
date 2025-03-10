# frozen_string_literal: true

require 'va_profile/models/validation_address'
require 'va_profile/address_validation/service'
require 'va_profile/models/v3/validation_address'
require 'va_profile/v3/address_validation/service'

ADDRESS_BATCH1 = [
  {
    poa: '091',
    address_line1: '9129 Veterans Drive SW',
    address_line2: nil,
    address_line3: nil,
    city: 'Lakewood',
    state_code: 'WA',
    zip_code: '98498',
    zip_suffix: nil
  },
  {
    poa: '022',
    address_line1: 'PO Box 1391',
    address_line2: nil,
    address_line3: nil,
    city: 'Montgomery',
    state_code: 'AL',
    zip_code: '36102',
    zip_suffix: '1509'
  },
  {
    poa: 'ABA',
    address_line1: '321 North Clark Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Chicago',
    state_code: 'IL',
    zip_code: '606544',
    zip_suffix: nil
  },
  {
    poa: '074',
    address_line1: '1608 K Street NW',
    address_line2: nil,
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20006',
    zip_suffix: nil
  },
  {
    poa: '075',
    address_line1: '425 I Street NW',
    address_line2: 'RM2w240B',
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20001',
    zip_suffix: nil
  },
  {
    poa: '077',
    address_line1: '4647 Forbes Boulevard',
    address_line2: nil,
    address_line3: nil,
    city: 'Lanham',
    state_code: 'MD',
    zip_code: '20706',
    zip_suffix: nil
  },
  {
    poa: '045',
    address_line1: '3839 N. Third Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Phoenix',
    state_code: 'AZ',
    zip_code: '85012',
    zip_suffix: nil
  },
  {
    poa: '050',
    address_line1: '2401 John Ashley Drive',
    address_line2: nil,
    address_line3: nil,
    city: 'North Little Rock',
    state_code: 'AR',
    zip_code: '72114',
    zip_suffix: nil
  },
  {
    poa: '078',
    address_line1: '2800 S. Shirlington Road',
    address_line2: 'Suite 350',
    address_line3: nil,
    city: 'Arlington',
    state_code: 'VA',
    zip_code: '22206',
    zip_suffix: '1953'
  },
  {
    poa: '079',
    address_line1: '35 St. John Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Niles',
    state_code: 'OH',
    zip_code: '44446',
    zip_suffix: nil
  },
  {
    poa: '080',
    address_line1: 'P.O. Box 90770',
    address_line2: nil,
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20090',
    zip_suffix: nil
  },
  {
    poa: '044',
    address_line1: 'Veterans Services Division',
    address_line2: "1227 'O' Steet",
    address_line3: 'Suite 500',
    city: 'Sacramento',
    state_code: 'CA',
    zip_code: '95814',
    zip_suffix: nil
  },
  {
    poa: '081',
    address_line1: '237-20 92nd Road',
    address_line2: nil,
    address_line3: nil,
    city: 'Bellerose',
    state_code: 'NY',
    zip_code: '11426',
    zip_suffix: nil
  },
  {
    poa: '039',
    address_line1: '155 Van Gordon St',
    address_line2: 'Suite 201',
    address_line3: nil,
    city: 'Lakewood',
    state_code: 'CO',
    zip_code: '80228',
    zip_suffix: nil
  },
  {
    poa: '008',
    address_line1: '287 West Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Rocky Hill',
    state_code: 'CT',
    zip_code: '06067',
    zip_suffix: nil
  },
  {
    poa: 'HW0',
    address_line1: '1233 West Lindsey Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Norman',
    state_code: 'OK',
    zip_code: '73069',
    zip_suffix: nil
  },
  {
    poa: '060',
    address_line1: '802 Silver Lake Boulevard',
    address_line2: 'Suite 100',
    address_line3: nil,
    city: 'Dover',
    state_code: 'DE',
    zip_code: '19904',
    zip_suffix: nil
  },
  {
    poa: '083',
    address_line1: '1300 I Street NW',
    address_line2: 'Suite 400 West',
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20005',
    zip_suffix: nil
  },
  {
    poa: '085',
    address_line1: '125 North West Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Alexandria',
    state_code: 'VA',
    zip_code: '22314',
    zip_suffix: '2754'
  },
  {
    poa: '017',
    address_line1: 'P.O. Box 31003',
    address_line2: nil,
    address_line3: nil,
    city: 'St. Petersburg',
    state_code: 'FL',
    zip_code: '33731',
    zip_suffix: nil
  }
].freeze

ADDRESS_BATCH2 = [
  {
    poa: '016',
    address_line1: 'Floyd Veterans Memorial Building',
    address_line2: '2 MLK, Jr. Drive, Suite E-970',
    address_line3: nil,
    city: 'Atlanta',
    state_code: 'GA',
    zip_code: '30334',
    zip_suffix: nil
  },
  {
    poa: 'JCV',
    address_line1: 'PO BOX 97',
    address_line2: nil,
    address_line3: nil,
    city: 'Sacaton',
    state_code: 'AZ',
    zip_code: '85147',
    zip_suffix: nil
  },
  {
    poa: 'HTC',
    address_line1: '14351 Blanco Rd',
    address_line2: nil,
    address_line3: nil,
    city: 'San Antonio',
    state_code: 'TX',
    zip_code: '78216',
    zip_suffix: '7723'
  },
  {
    poa: '059',
    address_line1: '459 Patterson Road',
    address_line2: 'E-Wing',
    address_line3: 'Room 1-A103',
    city: 'Honolulu',
    state_code: 'HI',
    zip_code: '96819',
    zip_suffix: nil
  },
  {
    poa: '047',
    address_line1: '351 Collins Road',
    address_line2: nil,
    address_line3: nil,
    city: 'Boise',
    state_code: 'ID',
    zip_code: '83702',
    zip_suffix: nil
  },
  {
    poa: '028',
    address_line1: '833 South Spring Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Springfield',
    state_code: 'IL',
    zip_code: '62791',
    zip_suffix: nil
  },
  {
    poa: 'E5L',
    address_line1: '302 West Washignton Street',
    address_line2: 'Room E120',
    address_line3: nil,
    city: 'Indianapolis',
    state_code: 'IN',
    zip_code: '46204',
    zip_suffix: nil
  },
  {
    poa: '033',
    address_line1: '210 Walnut Street',
    address_line2: 'Room 556',
    address_line3: nil,
    city: 'Des Moines',
    state_code: 'IA',
    zip_code: '50309',
    zip_suffix: nil
  },
  {
    poa: '095',
    address_line1: '4540 Clifton Avenue',
    address_line2: nil,
    address_line3: nil,
    city: 'Lorain',
    state_code: 'OH',
    zip_code: '44055',
    zip_suffix: nil
  },
  {
    poa: '086',
    address_line1: '1811 R St NW',
    address_line2: nil,
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20009',
    zip_suffix: nil
  },
  {
    poa: '052',
    address_line1: '700 SW Jackson',
    address_line2: 'Suite 701',
    address_line3: nil,
    city: 'Topeka',
    state_code: 'KS',
    zip_code: '66603',
    zip_suffix: nil
  },
  {
    poa: '027',
    address_line1: '310 W. Main Street',
    address_line2: 'Suite 390',
    address_line3: nil,
    city: 'Louisville',
    state_code: 'KY',
    zip_code: '40202',
    zip_suffix: nil
  },
  {
    poa: '087',
    address_line1: '3927 Rust Hill Place',
    address_line2: nil,
    address_line3: nil,
    city: 'Fairfax',
    state_code: 'VA',
    zip_code: '22030',
    zip_suffix: nil
  },
  {
    poa: '021',
    address_line1: 'PO Box 94095',
    address_line2: 'Capitol Station',
    address_line3: nil,
    city: 'Baton Rouge',
    state_code: 'LA',
    zip_code: '70804',
    zip_suffix: nil
  },
  {
    poa: '002',
    address_line1: '117 State House Station',
    address_line2: 'Bldg 248',
    address_line3: 'Room 110',
    city: 'Augusta',
    state_code: 'ME',
    zip_code: '04333',
    zip_suffix: nil
  },
  {
    poa: '088',
    address_line1: '3619 Jefferson Davis Hwy',
    address_line2: 'Suite 115',
    address_line3: nil,
    city: 'Stafford',
    state_code: 'VA',
    zip_code: '22554',
    zip_suffix: nil
  },
  {
    poa: '4R0',
    address_line1: 'Federal Building, Room 110',
    address_line2: '31 Hopkins Plaza',
    address_line3: nil,
    city: 'Baltimore',
    state_code: 'MD',
    zip_code: '21201',
    zip_suffix: nil
  },
  {
    poa: '4R3',
    address_line1: '600 Washington Street',
    address_line2: '7th Floor',
    address_line3: nil,
    city: 'Boston',
    state_code: 'MA',
    zip_code: '02111',
    zip_suffix: nil
  },
  {
    poa: '8FE',
    address_line1: '3423 N. Martin Luther King Jr. Blvd.',
    address_line2: nil,
    address_line3: nil,
    city: 'Lansing',
    state_code: 'MI',
    zip_code: '48906',
    zip_suffix: nil
  },
  {
    poa: 'A2I',
    address_line1: '201 N. Washington St.',
    address_line2: nil,
    address_line3: nil,
    city: 'Alexandria',
    state_code: 'VA',
    zip_code: '22314',
    zip_suffix: nil
  }
].freeze

ADDRESS_BATCH3 = [
  {
    poa: '035',
    address_line1: 'Bishop Henry Whipple Federal Building',
    address_line2: '1 Federal Drive, Room G220',
    address_line3: nil,
    city: 'St. Paul',
    state_code: 'MN',
    zip_code: '55111',
    zip_suffix: nil
  },
  {
    poa: '023',
    address_line1: '660 North Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Jackson',
    state_code: 'MS',
    zip_code: '39296',
    zip_suffix: nil
  },
  {
    poa: '031',
    address_line1: '205 Jefferson Street',
    address_line2: '12th Floor',
    address_line3: nil,
    city: 'Jefferson City',
    state_code: 'MO',
    zip_code: '65102',
    zip_suffix: nil
  },
  {
    poa: '036',
    address_line1: 'Joseph S. Foster, Administrator',
    address_line2: 'Department of Military Affairs',
    address_line3: 'P.O. Box 5715',
    city: 'Helena',
    state_code: 'MT',
    zip_code: '59604',
    zip_suffix: '5715'
  },
  {
    poa: '084',
    address_line1: 'PO BOX 9276',
    address_line2: nil,
    address_line3: nil,
    city: 'Portland',
    state_code: 'OR',
    zip_code: '97207',
    zip_suffix: nil
  },
  {
    poa: '064',
    address_line1: 'NACVSO',
    address_line2: '25 Massachusetts Ave, NW',
    address_line3: 'Suite 500',
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20001',
    zip_suffix: nil
  },
  {
    poa: 'FYT',
    address_line1: 'C/O Veterans Law Institute',
    address_line2: 'Stetson University Veterans Advocacy Clinic',
    address_line3: '1401 61st St. S.',
    city: 'Gulfport',
    state_code: 'FL',
    zip_code: '33707',
    zip_suffix: nil
  },
  {
    poa: 'JLW',
    address_line1: 'P.O. Box 40477',
    address_line2: nil,
    address_line3: nil,
    city: 'Mobile',
    state_code: 'AL',
    zip_code: '36640',
    zip_suffix: nil
  },
  {
    poa: '082',
    address_line1: '1100 Wilson Blvd.',
    address_line2: 'Suite 900',
    address_line3: nil,
    city: 'Arlington',
    state_code: 'VA',
    zip_code: '22209',
    zip_suffix: nil
  },
  {
    poa: '094',
    address_line1: 'PO Box 370005',
    address_line2: nil,
    address_line3: nil,
    city: 'El Paso',
    state_code: 'TX',
    zip_code: '79937',
    zip_suffix: nil
  },
  {
    poa: 'IP4',
    address_line1: 'PO Box 430',
    address_line2: nil,
    address_line3: nil,
    city: 'Window Rock',
    state_code: 'AZ',
    zip_code: '86515',
    zip_suffix: nil
  },
  {
    poa: '093',
    address_line1: '29 Carpenter Road',
    address_line2: nil,
    address_line3: nil,
    city: 'Arlington',
    state_code: 'VA',
    zip_code: '22212',
    zip_suffix: nil
  },
  {
    poa: '034',
    address_line1: '301 Centennial Mall, South 4th Floor',
    address_line2: 'PO Box 95083',
    address_line3: nil,
    city: 'Lincoln',
    state_code: 'NE',
    zip_code: '68509',
    zip_suffix: nil
  },
  {
    poa: '054',
    address_line1: '5460 Reno Corporate Drive',
    address_line2: '#131',
    address_line3: nil,
    city: 'Reno',
    state_code: 'NV',
    zip_code: '89511',
    zip_suffix: nil
  },
  {
    poa: '073',
    address_line1: 'Norris Cotton Federal Building',
    address_line2: '275 Chestnut Street, Room 517',
    address_line3: nil,
    city: 'Manchester',
    state_code: 'NH',
    zip_code: '03101',
    zip_suffix: '2411'
  },
  {
    poa: '009',
    address_line1: 'PO Box 340',
    address_line2: nil,
    address_line3: nil,
    city: 'Trenton',
    state_code: 'NJ',
    zip_code: '08625',
    zip_suffix: '0340'
  },
  {
    poa: '040',
    address_line1: '407 Galisteo Street',
    address_line2: 'Room 142',
    address_line3: nil,
    city: 'Santa Fe',
    state_code: 'NM',
    zip_code: '87501',
    zip_suffix: nil
  },
  {
    poa: '006',
    address_line1: '2 Empire State Plaza',
    address_line2: '17th Floor',
    address_line3: nil,
    city: 'Albany',
    state_code: 'NY',
    zip_code: '12223',
    zip_suffix: '1551'
  },
  {
    poa: '018',
    address_line1: '4001 Mail Service Center',
    address_line2: nil,
    address_line3: nil,
    city: 'Raleigh',
    state_code: 'NC',
    zip_code: '27699',
    zip_suffix: '4001'
  },
  {
    poa: '037',
    address_line1: '4201 38th Street S',
    address_line2: '#104',
    address_line3: nil,
    city: 'Fargo',
    state_code: 'ND',
    zip_code: '58104',
    zip_suffix: nil
  }
].freeze

ADDRESS_BATCH4 = [
  {
    poa: '4R2',
    address_line1: '233 Unknow Road',
    address_line2: nil,
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20420',
    zip_suffix: nil
  },
  {
    poa: '025',
    address_line1: '77 South High Street',
    address_line2: '7th Floor',
    address_line3: nil,
    city: 'Columbus',
    state_code: 'OH',
    zip_code: '43215',
    zip_suffix: nil
  },
  {
    poa: '051',
    address_line1: '125 South Main Street',
    address_line2: 'Room 1B38',
    address_line3: nil,
    city: 'Muskogee',
    state_code: 'OK',
    zip_code: '74401',
    zip_suffix: nil
  },
  {
    poa: '048',
    address_line1: '700 Summer Street NE',
    address_line2: nil,
    address_line3: nil,
    city: 'Salem',
    state_code: 'OR',
    zip_code: '97310',
    zip_suffix: nil
  },
  {
    poa: '071',
    address_line1: '1875 Eye Street NW',
    address_line2: 'Suite 1100',
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20006',
    zip_suffix: nil
  },
  {
    poa: '010',
    address_line1: 'Fort Indiantown Gap',
    address_line2: 'Building S-O-47',
    address_line3: nil,
    city: 'Annville',
    state_code: 'PA',
    zip_code: '17003',
    zip_suffix: '5002'
  },
  {
    poa: '003',
    address_line1: '6410 Sunstrip Drive',
    address_line2: nil,
    address_line3: nil,
    city: 'Austin',
    state_code: 'TX',
    zip_code: '78745',
    zip_suffix: nil
  },
  {
    poa: '004',
    address_line1: '560 Jefferson Blvd.',
    address_line2: 'Suite 206',
    address_line3: nil,
    city: 'Warwick',
    state_code: 'RI',
    zip_code: '02886',
    zip_suffix: nil
  },
  {
    poa: '038',
    address_line1: '2501 West 22nd Street, Box 5046',
    address_line2: nil,
    address_line3: nil,
    city: 'Sioux Falls',
    state_code: 'SD',
    zip_code: '57117',
    zip_suffix: nil
  },
  {
    poa: '043',
    address_line1: '1060 Howard Street',
    address_line2: nil,
    address_line3: nil,
    city: 'San Francisco',
    state_code: 'CA',
    zip_code: '94103',
    zip_suffix: nil
  },
  {
    poa: '020',
    address_line1: 'Federal Building, U.S. Courthouse',
    address_line2: '110 9th Avenue South, Room C-166',
    address_line3: nil,
    city: 'Nashville',
    state_code: 'TN',
    zip_code: '37203',
    zip_suffix: nil
  },
  {
    poa: '049',
    address_line1: '1700 N. Congress Ave.',
    address_line2: 'Suite 800',
    address_line3: nil,
    city: 'Austin',
    state_code: 'TX',
    zip_code: '78701',
    zip_suffix: nil
  },
  {
    poa: '007',
    address_line1: '12200 E. Briarwood Suite 250',
    address_line2: nil,
    address_line3: nil,
    city: 'Centennial',
    state_code: 'CO',
    zip_code: '80112',
    zip_suffix: nil
  },
  {
    poa: '019',
    address_line1: '477 Edgar Brown State Office Building',
    address_line2: '1205 Pendleton Street',
    address_line3: nil,
    city: 'Columbia',
    state_code: 'SC',
    zip_code: '29201',
    zip_suffix: nil
  },
  {
    poa: '096',
    address_line1: 'PO Box 1915',
    address_line2: nil,
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20013',
    zip_suffix: nil
  },
  {
    poa: '090',
    address_line1: 'PO Box 42938',
    address_line2: nil,
    address_line3: nil,
    city: 'Philadelphia',
    state_code: 'PA',
    zip_code: '19101',
    zip_suffix: nil
  },
  {
    poa: '041',
    address_line1: '550 Foothill Boulevard',
    address_line2: 'Room 202',
    address_line3: nil,
    city: 'Salt Lake City',
    state_code: 'UT',
    zip_code: '84108',
    zip_suffix: nil
  },
  {
    poa: '005',
    address_line1: '118 State Street',
    address_line2: nil,
    address_line3: nil,
    city: 'Montpelier',
    state_code: 'VT',
    zip_code: '05620',
    zip_suffix: nil
  },
  {
    poa: '097',
    address_line1: '200 Maryland Avenue NE',
    address_line2: nil,
    address_line3: nil,
    city: 'Washington',
    state_code: 'DC',
    zip_code: '20002',
    zip_suffix: nil
  },
  {
    poa: '4R4',
    address_line1: 'PO Box 1741',
    address_line2: nil,
    address_line3: nil,
    city: 'Plains',
    state_code: 'PA',
    zip_code: '18705',
    zip_suffix: nil
  }
].freeze

ADDRESS_BATCH5 = [
  {
    poa: 'J3C',
    address_line1: '8719 Colesville Road',
    address_line2: 'Suite 100',
    address_line3: nil,
    city: 'Silver Spring',
    state_code: 'MD',
    zip_code: '20910',
    zip_suffix: nil
  },
  {
    poa: '070',
    address_line1: '8719 Colesville Road',
    address_line2: 'Suite 100',
    address_line3: nil,
    city: 'Silver Spring',
    state_code: 'MD',
    zip_code: '20910',
    zip_suffix: nil
  },
  {
    poa: '014',
    address_line1: '101 North 14th Street',
    address_line2: '17th Floor',
    address_line3: nil,
    city: 'Richmond',
    state_code: 'VA',
    zip_code: '23219',
    zip_suffix: nil
  },
  {
    poa: '046',
    address_line1: '1102 Quince Street SE',
    address_line2: 'PO Box 41150',
    address_line3: nil,
    city: 'Olympia',
    state_code: 'WA',
    zip_code: '98504',
    zip_suffix: nil
  },
  {
    poa: '015',
    address_line1: '1514 B Kanawha Blvd. East',
    address_line2: nil,
    address_line3: nil,
    city: 'Charleston',
    state_code: 'WV',
    zip_code: '25311',
    zip_suffix: nil
  },
  {
    poa: '030',
    address_line1: '2135 Rimrock Road',
    address_line2: 'PO Box 7843',
    address_line3: nil,
    city: 'Madison',
    state_code: 'WI',
    zip_code: '53707',
    zip_suffix: '7843'
  },
  {
    poa: '00V',
    address_line1: '2200 Space Park Drive',
    address_line2: 'Suite 100',
    address_line3: nil,
    city: 'Houston',
    state_code: 'TX',
    zip_code: '77027',
    zip_suffix: nil
  },
  {
    poa: '869',
    address_line1: '5410 Bishop Blvd.',
    address_line2: nil,
    address_line3: nil,
    city: 'Cheyenne',
    state_code: 'WY',
    zip_code: '82009',
    zip_suffix: nil
  }
].freeze

# Constructs a validation address object from the provided address data.
# @param org [Hash] A hash containing the details of the organization's address.
# @return [VAProfile::Models::ValidationAddress] A validation address object ready for address validation service.
def build_validation_address(org)
  validation_model = if Flipper.enabled?(:remove_pciu)
                       VAProfile::Models::V3::ValidationAddress
                     else
                       VAProfile::Models::ValidationAddress
                     end
  validation_model.new(
    address_pou: org[:address_pou],
    address_line1: org[:address_line1],
    address_line2: org[:address_line2],
    address_line3: org[:address_line3],
    city: org[:city],
    state_code: org[:state_code],
    zip_code: org[:zip_code],
    zip_code_suffix: org[:zip_suffix],
    country_code_iso3: 'US'
  )
end

# Validates the given address using the VAProfile address validation service.
# @param candidate_address [VAProfile::Models::ValidationAddress] The address to be validated.
# @return [Hash] The response from the address validation service.
def validate_address(candidate_address)
  validation_service = if Flipper.enabled?(:remove_pciu)
                         VAProfile::V3::AddressValidation::Service.new
                       else
                         VAProfile::AddressValidation::Service.new
                       end
  validation_service.candidate(candidate_address)
end

# Checks if the address validation response is valid.
# @param api_response [Hash] The response from the address validation service.
# @return [Boolean] True if the address is valid, false otherwise.
def address_valid?(api_response)
  api_response.key?('candidate_addresses') && !api_response['candidate_addresses'].empty?
end

# Builds a hash of the standard address fields from the address validation response.
# @param api_response [Hash] The response from the address validation service.
# @return [Hash] A hash of the standard address fields.
def build_valid_address_attributes(api_response)
  address = api_response['candidate_addresses'].first['address']

  {
    address_line1: address['address_line1'],
    address_line2: address['address_line2'],
    address_line3: address['address_line3'],
    city: address['city'],
    state_code: address['state_province']['code'],
    zip_code: address['zip_code5'],
    zip_suffix: address['zip_code4'],
    province: nil,
    country_code_iso3: nil,
    country_name: nil,
    county_name: nil,
    county_code: nil,
    lat: nil,
    long: nil,
    location: nil
  }
end

# Builds a hash of all address fields and sets them to nil.
# @return [Hash] A hash of all address fields.
def build_null_address_attributes
  {
    address_type: nil,
    address_line1: nil,
    address_line2: nil,
    address_line3: nil,
    city: nil,
    state_code: nil,
    zip_code: nil,
    zip_suffix: nil,
    province: nil,
    country_code_iso3: nil,
    country_name: nil,
    county_name: nil,
    county_code: nil,
    lat: nil,
    long: nil,
    location: nil
  }
end

# Task: Update VSO (Veteran Service Organization) Addresses
#
# This task updates addresses for VSOs by validating them through the VAProfile address validation service.
# It can be run with a default set of addresses or with a custom set specified by a constant.
#
# Usage:
# To run this task with the default address set (ADDRESSES), use:
#   bundle exec rake veteran:update_vso_addresses
#
# To run this task with a custom set of addresses defined by a constant (e.g., ADDRESS_BATCH2), you need to specify the constant name. # rubocop:disable Layout/LineLength
# Note: The command syntax can differ slightly depending on your shell environment.
#
# For bash or similar shells, use:
#   bundle exec rake 'veteran:update_vso_addresses[ADDRESS_BATCH2]'
#
# For zsh (which requires escaping square brackets or quoting the entire command), use one of the following:
#   bundle exec rake veteran:update_vso_addresses\[ADDRESS_BATCH2\]
#   bundle exec rake 'veteran:update_vso_addresses[ADDRESS_BATCH2]'
#
# After running the task, please wait about 60 seconds before running it again to avoid rate limiting.
namespace :veteran do
  desc 'Update VSO (organization) Addresses'
  task :update_vso_addresses, [:constant_name] => :environment do |_t, args|
    constant_name = args[:constant_name] || 'ADDRESS_BATCH1'
    addresses = Object.const_get(constant_name)
    num_records_updated = 0
    num_invalid_addresses = 0
    num_records_not_found = 0
    num_records_errored = 0
    errors = []

    addresses.each do |org|
      candidate_address = build_validation_address(org)
      api_response = validate_address(candidate_address)
      record = Veteran::Service::Organization.find(org[:poa])

      if address_valid?(api_response)
        record.update(build_valid_address_attributes(api_response))
      else
        record.update(build_null_address_attributes)
        num_invalid_addresses += 1
      end

      num_records_updated += 1
    rescue ActiveRecord::RecordNotFound
      num_records_not_found += 1
    rescue => e
      num_records_errored += 1
      errors << "Error updating organization address for POA in Organizations::UpdateNames: #{e.message}. POA: '#{org[:poa]}'." # rubocop:disable Layout/LineLength
    end

    puts "Total number of records: #{addresses.size}"
    puts "Number of records updated: #{num_records_updated}"
    puts "Number of invalid addresses: #{num_invalid_addresses}"
    puts "Number of records not found: #{num_records_not_found}"
    puts "Number of records errored: #{num_records_errored}"
    puts "Errors:\n#{errors.join("\n")}"
  end
end
