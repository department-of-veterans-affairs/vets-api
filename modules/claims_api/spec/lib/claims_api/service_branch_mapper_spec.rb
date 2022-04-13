# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/service_branch_mapper'

SERVICE_BRANCH_VALUE_MAPPINGS = {
  'Air Force' => 'Air Force',
  'Air Force Academy' => 'Air Force Academy',
  'Air Force Reserves' => 'Air Force Reserves',
  'Air Force Civilian' => 'Other',
  'Air National Guard' => 'Air National Guard',
  'Army' => 'Army',
  'Army Air Corps' => 'Army Air Corps or Army Air Force',
  'Army Air Corps or Army Air Force' => 'Army Air Corps or Army Air Force',
  'Army National Guard' => 'Army National Guard',
  'Army Nurse Corps' => 'Army',
  'Army Reserves' => 'Army Reserves',
  'Coast Guard' => 'Coast Guard',
  'Coast Guard Academy' => 'Coast Guard Academy',
  'Coast Guard Reserves' => 'Coast Guard Reserves',
  'Commonwealth Army Veteran' => 'Other',
  'Guerrilla Combination Service' => 'Other',
  'Marine' => 'Marine Corps',
  'Marine Corps' => 'Marine Corps',
  'Marine Corps Reserves' => 'Marine Corps Reserves',
  'Merchant Marine' => 'Merchant Marine',
  'National Oceanic and Atmospheric Administration' => 'National Oceanic & Atmospheric Administration',
  'Naval Academy' => 'Naval Academy',
  'Navy' => 'Navy',
  'Navy Reserves' => 'Navy Reserves',
  'Other' => 'Other',
  'Public Health Service' => 'Public Health Service',
  'Regular Philippine Scout' => 'Other',
  'Regular Scout Service' => 'Other',
  'Special Philippine Scout' => 'Other',
  'Unknown' => 'Other',
  'US Military Academy' => 'US Military Academy',
  'Woman Air Corps' => 'Other',
  "Women's Army Corps" => "Women's Army Corps"
}.freeze

describe ClaimsApi::ServiceBranchMapper do
  SERVICE_BRANCH_VALUE_MAPPINGS.each do |key, value|
    context "when 'serviceBranch' is '#{key}'" do
      it "maps to '#{value}'" do
        mapped_value = ClaimsApi::ServiceBranchMapper.new(key).value
        expect(mapped_value).to eq(value)
      end
    end
  end
end
