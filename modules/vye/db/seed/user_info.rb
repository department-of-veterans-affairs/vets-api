#!/usr/bin/env ruby
# frozen_string_literal: true

module Vye; end
module Vye::Seed; end

module Vye::Seed::UserInfo
  module_function

  def tud_users
    team_sensitive_root = Rails.root / '../va.gov-team-sensitive'
    csv = CSV.read(team_sensitive_root / 'Administrative/vagov-users/test_users.csv', headers: true)
    found_ssn = csv.each_with_object([]) do |u, a|
      a.push(u['ssn']) if u['ssn'].present?
    end.compact

    csv.each_with_object([]) do |u, result|
      full_name = u.values_at('first_name', 'middle_name', 'last_name').compact.map(&:capitalize).join(' ')
      ssn = u['ssn']
      dob = u['birth_date']

      next unless ssn.present? && found_ssn.include?(ssn)

      found_ssn.delete(ssn)

      result.push({ full_name:, ssn:, dob: })
    end
  end

  def user_attributes
    tud_users.map do |u|
      f = FactoryBot.attributes_for(:vye_user_info).except(:full_name, :ssn, :dob)
      u.update(f)
    end
  end

  def create_users
    user_attributes.each do |u|
      Vye::UserInfo.create!(u)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  require 'pathname'
  ENGINE_ROOT = Pathname(__dir__) / '../..'
  RAILS_ROOT = ENGINE_ROOT / '../..'

  require_relative(RAILS_ROOT / 'config/environment')
  Vye::Seed::UserInfo.create_users
  Rails.logger.debug { "Created #{Vye::UserInfo.count} users" }
else
  Vye::Seed::UserInfo.create_users
end
