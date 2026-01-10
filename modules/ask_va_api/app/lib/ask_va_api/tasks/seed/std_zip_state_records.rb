# frozen_string_literal: true

module AskVAApi
  module Seed
    module StdZipStateRecords
      STATE_CODES = %w[CA TX NY PA].freeze

      STATES = [
        { postal_name: 'CA', name: 'California', fips_code: 06, country_id: 1006840 },
        { postal_name: 'NY', name: 'New York', fips_code: 36, country_id: 1006840 },
        { postal_name: 'PA', name: 'Pennsylvania', fips_code: 42, country_id: 1006840 },
        { postal_name: 'TX', name: 'Texas', fips_code: 48, country_id: 1006840 },
      ].freeze
      
      ZIPCODES = [
        { zip_code: '90001', state_code: 'CA', county_number: 037 },
        { zip_code: '90002', state_code: 'CA', county_number: 037 },
        { zip_code: '90003', state_code: 'CA', county_number: 037 },
        { zip_code: '90004', state_code: 'CA', county_number: 037 },
        { zip_code: '90005', state_code: 'CA', county_number: 037 },
        { zip_code: '90006', state_code: 'CA', county_number: 037 },
        { zip_code: '90007', state_code: 'CA', county_number: 037 },
        { zip_code: '90008', state_code: 'CA', county_number: 037 },
        { zip_code: '90009', state_code: 'CA', county_number: 037 },
        { zip_code: '90010', state_code: 'CA', county_number: 037 },
        { zip_code: '73301', state_code: 'TX', county_number: 453 },
        { zip_code: '73344', state_code: 'TX', county_number: 453 },
        { zip_code: '73960', state_code: 'TX', county_number: 421 },
        { zip_code: '75001', state_code: 'TX', county_number: 113 },
        { zip_code: '75002', state_code: 'TX', county_number: 085 },
        { zip_code: '75006', state_code: 'TX', county_number: 113 },
        { zip_code: '75007', state_code: 'TX', county_number: 121 },
        { zip_code: '75008', state_code: 'TX', county_number: 121 },
        { zip_code: '75009', state_code: 'TX', county_number: 085 },
        { zip_code: '75010', state_code: 'TX', county_number: 121 },
        { zip_code: '00501', state_code: 'NY', county_number: 103 },
        { zip_code: '00544', state_code: 'NY', county_number: 103 },
        { zip_code: '06390', state_code: 'NY', county_number: 103 },
        { zip_code: '10001', state_code: 'NY', county_number: 061 },
        { zip_code: '10002', state_code: 'NY', county_number: 061 },
        { zip_code: '10003', state_code: 'NY', county_number: 061 },
        { zip_code: '10004', state_code: 'NY', county_number: 061 },
        { zip_code: '10005', state_code: 'NY', county_number: 061 },
        { zip_code: '10006', state_code: 'NY', county_number: 061 },
        { zip_code: '10007', state_code: 'NY', county_number: 061 },
        { zip_code: '15001', state_code: 'PA', county_number: 007 },
        { zip_code: '15003', state_code: 'PA', county_number: 007 },
        { zip_code: '15004', state_code: 'PA', county_number: 125 },
        { zip_code: '15005', state_code: 'PA', county_number: 007 },
        { zip_code: '15006', state_code: 'PA', county_number: 003 },
        { zip_code: '15007', state_code: 'PA', county_number: 003 },
        { zip_code: '15009', state_code: 'PA', county_number: 007 },
        { zip_code: '15010', state_code: 'PA', county_number: 007 },
        { zip_code: '15012', state_code: 'PA', county_number: 051 },
        { zip_code: '15014', state_code: 'PA', county_number: 003 },
      ].freeze
    end
  end
end
