# frozen_string_literal: true

require 'csv'

Rails.application.reloader.to_prepare do
  ZCTA = CSV.read(Rails.root.join('lib', 'facilities', '2019_Gaz_zcta_national.tsv'),
                  col_sep: "\t", headers: true).index_by { |row| row[0] }
  ZCTA_LAT_HEADER = 'INTPTLAT'
  ZCTA_LON_HEADER = 'INTPTLONG'
end
