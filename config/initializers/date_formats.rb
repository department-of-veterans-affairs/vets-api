# frozen_string_literal: true

# These entries represent the possible formats for a Date for a to_s call
Date::DATE_FORMATS[:iso8601] = '%Y-%m-%d'
Date::DATE_FORMATS[:number_iso8601] = '%Y%m%d'
Date::DATE_FORMATS[:datetime_iso8601] = '%FT%T%:z'
Date::DATE_FORMATS[:month_day_year] = '%b %d, %Y'
