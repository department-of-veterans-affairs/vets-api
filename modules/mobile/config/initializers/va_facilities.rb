# frozen_string_literal: true

# Dictionary of TZ Database timezone names (the physical location of the time zone)
# looked up by the the time zone schedule for the region (standard vs daylight savings time)

Mobile::VA_TZ_DATABASE_NAMES_BY_SCHEDULE = {
  'AKST' => 'America/Anchorage',
  'AKDT' => 'America/Anchorage',
  'AST' => 'America/Argentina/San_Juan',
  'CDT' => 'America/Chicago',
  'CST' => 'America/Chicago',
  'EDT' => 'America/New_York',
  'EST' => 'America/New_York',
  'HST' => 'Pacific/Honolulu',
  'MDT' => 'America/Denver',
  'MST' => 'America/Denver',
  'PHST' => 'Asia/Manila',
  'PDT' => 'America/Los_Angeles',
  'PST' => 'America/Los_Angeles'
}.freeze

# Dictionary of facility names and time zones by facility id
# This data currently is unavailable via API and although appointment times
# include an ISO 8601 Z offset that is not sufficient to determine the time zone
# see [Time Zone != Offset](https://stackoverflow.com/tags/timezone/info)

Mobile::VA_FACILITIES_BY_ID = {
  'dfn-358' => {
    name: 'MANILA VAMC',
    time_zone: 'Asia/Manila'
  },
  'dfn-519' => {
    name: 'WEST TEXAS HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-523' => {
    name: 'BOSTON HCS VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-548' => {
    name: 'WEST PALM BEACH VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-552' => {
    name: 'DAYTON',
    time_zone: 'America/New_York'
  },
  'dfn-585' => {
    name: 'IRON MOUNTAIN VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-657' => {
    name: 'ST. LOUIS MO VAMC-JC DIVISION',
    time_zone: 'America/Chicago'
  },
  'dfn-668' => {
    name: 'SPOKANE VAMC',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-671' => {
    name: 'SOUTH TEXAS HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-675' => {
    name: 'ORLANDO VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-506' => {
    name: 'ANN ARBOR VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-526' => {
    name: 'BRONX VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-608' => {
    name: 'MANCHESTER VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-632' => {
    name: 'NORTHPORT VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-437' => {
    name: 'FARGO VA HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-518' => {
    name: 'BEDFORD VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-562' => {
    name: 'ERIE VAMC',
    time_zone: 'America/New_York'

  },
  'dfn-612' => {
    name: 'NORTHERN CALIFORNIA HCS',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-613' => {
    name: 'MARTINSBURG VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-618' => {
    name: 'MINNEAPOLIS VA HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-629' => {
    name: 'SE LOUISIANA VETERANS HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-637' => {
    name: 'ASHEVILLE VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-674' => {
    name: 'CENTRAL TEXAS HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-687' => {
    name: 'WALLA WALLA VAMC',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-540' => {
    name: 'CLARKSBURG VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-550' => {
    name: 'ILLIANA HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-553' => {
    name: 'DETROIT, MI VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-583' => {
    name: 'INDIANAPOLIS VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-642' => {
    name: 'PHILADELPHIA, PA VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-660' => {
    name: 'SALT LAKE CITY HCS',
    time_zone: 'America/Denver'
  },
  'dfn-688' => {
    name: 'WASHINGTON',
    time_zone: 'America/New_York'
  },
  'dfn-512' => {
    name: 'BALTIMORE MD VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-459' => {
    name: 'VA PACIFIC ISLANDS HCS',
    time_zone: 'Pacific/Honolulu'
  },
  'dfn-573' => {
    name: 'N. FLORIDA/S. GEORGIA VHS',
    time_zone: 'America/New_York'
  },
  'dfn-640' => {
    name: 'PALO ALTO HCS',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-648' => {
    name: 'PORTLAND (OR) VAMC',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-650' => {
    name: 'PROVIDENCE VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-655' => {
    name: 'SAGINAW',
    time_zone: 'America/New_York'
  },
  'dfn-537' => {
    name: 'JESSE BROWN VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-541' => {
    name: 'CLEVELAND VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-556' => {
    name: 'CAPTN JAMES LOVELL FED HLT CTR',
    time_zone: 'America/Chicago'
  },
  'dfn-561' => {
    name: 'EAST ORANGE-VA NEW JERSEY HCS',
    time_zone: 'America/New_York'
  },
  'dfn-564' => {
    name: 'FAYETTEVILLE AR',
    time_zone: 'America/Chicago'
  },
  'dfn-596' => {
    name: 'LEXINGTON-LD VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-621' => {
    name: 'MOUNTAIN HOME VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-656' => {
    name: 'ST. CLOUD VA HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-659' => {
    name: 'SALISBURY VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-693' => {
    name: 'WILKES-BARRE VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-436' => {
    name: 'FORT HARRISON VAMC',
    time_zone: 'America/Denver'
  },
  'dfn-528' => {
    name: 'UPSTATE NEW YORK HCS',
    time_zone: 'America/New_York'
  },
  'dfn-534' => {
    name: 'CHARLESTON VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-538' => {
    name: 'CHILLICOTHE, OH VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-554' => {
    name: 'EASTERN COLORADO HCS',
    time_zone: 'America/Denver'
  },
  'dfn-603' => {
    name: 'LOUISVILLE, KY VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-666' => {
    name: 'SHERIDAN HCS',
    time_zone: 'America/Denver'
  },
  'dfn-689' => {
    name: 'CONNECTICUT HCS',
    time_zone: 'America/New_York'
  },
  'dfn-442' => {
    name: 'CHEYENNE VAMC',
    time_zone: 'America/Denver'
  },
  'dfn-503' => {
    name: 'ALTOONA',
    time_zone: 'America/New_York'
  },
  'dfn-575' => {
    name: 'GRAND JUNCTION (VAMC)',
    time_zone: 'America/Denver'
  },
  'dfn-590' => {
    name: 'HAMPTON (VAMC)',
    time_zone: 'America/New_York'
  },
  'dfn-598' => {
    name: 'CENTRAL ARKANSAS HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-620' => {
    name: 'HUDSON VALLEY HCS VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-623' => {
    name: 'JACK C. MONTGOMERY VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-636' => {
    name: 'VA NWIHS, OMAHA DIVISION',
    time_zone: 'America/Chicago'
  },
  'dfn-595' => {
    name: 'LEBANON VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-593' => {
    name: 'SOUTHERN NEVADA HCS',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-756' => {
    name: 'EL PASO VA HCS',
    time_zone: 'America/Denver'
  },
  'dfn-757' => {
    name: 'COLUMBUS VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-405' => {
    name: 'WHITE RIVER JUNCT VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-531' => {
    name: 'BOISE VAMC',
    time_zone: 'America/Denver'
  },
  'dfn-542' => {
    name: 'COATESVILLE VAMC',
    time_zone: 'America/New_York'

  },
  'dfn-549' => {
    name: 'NORTH TEXAS HCS',
    time_zone: 'America/Chicago'

  },
  'dfn-558' => {
    name: 'DURHAM VAMC',
    time_zone: 'America/New_York'

  },
  'dfn-565' => {
    name: 'FAYETTEVILLE NC VAMC',
    time_zone: 'America/New_York'

  },
  'dfn-570' => {
    name: 'CENTRAL CALIFORNIA HCS',
    time_zone: 'America/Los_Angeles'

  },
  'dfn-581' => {
    name: 'HUNTINGTON VAMC',
    time_zone: 'America/New_York'

  },
  'dfn-631' => {
    name: 'VA CNTRL WSTRN MASSCHUSETS HCS',
    time_zone: 'America/New_York'

  },
  'dfn-673' => {
    name: 'TAMPA VAMC',
    time_zone: 'America/New_York'

  },
  'dfn-672' => {
    name: 'SAN JUAN VAMC',
    time_zone: 'America/Puerto_Rico'

  },
  'dfn-740' => {
    name: 'TEXAS VALLEY COASTAL BEND HCS',
    time_zone: 'America/Chicago'

  },
  'dfn-463' => {
    name: 'ANCHORAGE VA HCS',
    time_zone: 'America/Anchorage'

  },
  'dfn-501' => {
    name: 'NEW MEXICO HCS',
    time_zone: 'America/Denver'

  },
  'dfn-515' => {
    name: 'BATTLE CREEK VAMC',
    time_zone: 'America/New_York'

  },
  'dfn-568' => {
    name: 'BLACK HILLS HCS',
    time_zone: 'America/Denver'

  },
  'dfn-580' => {
    name: 'HOUSTON VAMC',
    time_zone: 'America/Chicago'

  },
  'dfn-619' => {
    name: 'CENTRAL ALABAMA HCS',
    time_zone: 'America/Chicago'

  },
  'dfn-654' => {
    name: 'SIERRA NEVADA HCS',
    time_zone: 'America/Los_Angeles'

  },
  'dfn-663' => {
    name: 'PUGET SOUND HCS',
    time_zone: 'America/Los_Angeles'

  },
  'dfn-676' => {
    name: 'TOMAH VAMC',
    time_zone: 'America/Chicago'

  },
  'dfn-679' => {
    name: 'TUSCALOOSA',
    time_zone: 'America/Chicago'

  },
  'dfn-402' => {
    name: 'VA MAINE HCS',
    time_zone: 'America/New_York'

  },
  'dfn-520' => {
    name: 'BILOXI VAMC',
    time_zone: 'America/Chicago'

  },
  'dfn-649' => {
    name: 'NORTHERN ARIZONA HCS',
    time_zone: 'America/Phoenix'
  },
  'dfn-658' => {
    name: 'SALEM VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-662' => {
    name: 'SAN FRANCISCO VAMC',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-678' => {
    name: 'SOUTHERN ARIZONA VA HCS',
    time_zone: 'America/Phoenix'
  },
  'dfn-438' => {
    name: 'SIOUX FALLS VA HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-502' => {
    name: 'ALEXANDRIA VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-504' => {
    name: 'AMARILLO HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-509' => {
    name: 'AUGUSTA VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-517' => {
    name: 'BECKLEY VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-539' => {
    name: 'CINCINNATI',
    time_zone: 'America/New_York'
  },
  'dfn-578' => {
    name: 'HINES, IL VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-586' => {
    name: 'JACKSON VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-600' => {
    name: 'LONG BEACH VAMC',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-626' => {
    name: 'TENNESSEE VALLEY HCS',
    time_zone: 'America/Chicago'
  },
  'dfn-644' => {
    name: 'PHOENIX VAMC',
    time_zone: 'America/Phoenix'
  },
  'dfn-646' => {
    name: 'PITTSBURGH (UD), PA VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-652' => {
    name: 'RICHMOND VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-664' => {
    name: 'SAN DIEGO HCS',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-667' => {
    name: 'SHREVEPORT VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-691' => {
    name: 'WEST LA VAMC',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-460' => {
    name: 'WILMINGTON VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-521' => {
    name: 'BIRMINGHAM VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-529' => {
    name: 'BUTLER',
    time_zone: 'America/New_York'
  },
  'dfn-546' => {
    name: 'MIAMI VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-605' => {
    name: 'LOMA LINDA HCS',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-607' => {
    name: 'WILLIAM S. MIDDLETON VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-610' => {
    name: 'MARION, IN',
    time_zone: 'America/New_York'
  },
  'dfn-630' => {
    name: 'NEW YORK HHS',
    time_zone: 'America/New_York'
  },
  'dfn-653' => {
    name: 'ROSEBURG HCS',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-695' => {
    name: 'MILWAUKEE VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-508' => {
    name: 'ATLANTA VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-544' => {
    name: 'COLUMBIA, SC VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-557' => {
    name: 'DUBLIN VAMC',
    time_zone: 'America/New_York'
  },
  'dfn-589' => {
    name: 'VA HEARTLAND - WEST, VISN 15',
    time_zone: 'America/Chicago'
  },
  'dfn-614' => {
    name: 'MEMPHIS VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-635' => {
    name: 'OKLAHOMA CITY VAMC',
    time_zone: 'America/Chicago'
  },
  'dfn-692' => {
    name: 'WHITE CITY VAMC',
    time_zone: 'America/Los_Angeles'
  },
  'dfn-516' => {
    name: 'Bay Pines VA Healthcare System',
    time_zone: 'America/New_York'

  },
  'dfn-983' => {
    name: 'CHYSHR-Cheyenne VA Medical Center',
    time_zone: 'America/Denver'
  },
  'dfn-984' => {
    name: 'DAYTSHR-Dayton VA Medical Center',
    time_zone: 'America/New_York'
  }
}.freeze
