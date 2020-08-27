# frozen_string_literal: true

require 'csv'

ZCTA = CSV.read(Rails.root.join('lib', 'facilities', '2018_Gaz_zcta_national.txt'), col_sep: "\t")
