# frozen_string_literal: true

class Institution < ActiveRecord::Base
  include Tristateable

  EMPLOYER = 'ojt'
  LOCALE = {
    11 => 'City',
    12 => 'City',
    13 => 'City',
    21 => 'Suburban',
    22 => 'Suburban',
    23 => 'Suburban',
    31 => 'Town',
    32 => 'Town',
    33 => 'Town',
    41 => 'Rural',
    42 => 'Rural',
    43 => 'Rural'
  }.freeze
  DEGREES = {
    0 => nil,
    'ncd' => 'Certificate',
    1 => 'Certificate',
    '2-year' => 2,
    2 => 2,
    3 => 4,
    4 => 4,
    '4-year' => 4
  }.freeze

  belongs_to :institution_type, inverse_of: :institutions

  validates :facility_code, uniqueness: true, presence: true
  validates :institution_type_id, presence: true
  validates :institution, presence: true
  validates :country, presence: true

  scope :with_type, lambda {
    select('institutions.*, institution_types.name').joins(:institution_type)
  }

  def credit_for_mil_training
    tristate_boolean(:credit_for_mil_training)
  end

  def vet_poc
    tristate_boolean(:vet_poc)
  end

  def student_vet_grp_ipeds
    tristate_boolean(:student_vet_grp_ipeds)
  end

  def soc_member
    tristate_boolean(:soc_member)
  end

  def online_all
    tristate_boolean(:online_all)
  end

  # returns true if school is a correspondence school
  #
  def correspondence?
    institution_type.name.casecmp('correspondence').zero?
  end

  # returns true if school is a flight school
  #
  def flight?
    institution_type.name.casecmp('flight').zero?
  end

  # returns true if school is ojt.
  #
  def ojt?
    institution_type.name.casecmp('ojt').zero?
  end

  # returns true if school is not ojt.
  #
  def school?
    !institution_type.name.casecmp('ojt').zero?
  end

  # returns true if school is in USA
  #
  def in_usa?
    country.try(:downcase) == 'usa'
  end

  # Gets the locale name correpsonding to the locale
  #
  def locale_name
    LOCALE[locale] || 'Locale Unknown'
  end

  # Given a search term representing a partial school name, returns all
  # schools starting with the search term.
  #
  def self.autocomplete(search_term)
    search_term = search_term.to_s.strip.downcase
    Institution.select('id, facility_code as value, institution as label')
               .where('lower(institution) LIKE (?)', "#{search_term}%")
  end

  #############################################################################
  ## search
  ## Searchs for schools containing the search_term in their name or city.
  ## Also used when a facility_code is passed in.
  ##
  ## Search for cities and institutions are based on LIKE %term% and will
  ## return every city and institution matching the wildcard %term%. Searching
  ## by facility code is exact match.
  ##
  ## NOTE: facility_code is used for uniqueness, therefore it is possible that
  ## schools might appear to be duplicated since they have the same name but
  ## different facility codes.
  #############################################################################
  def self.search(search_term)
    if search_term.empty?
      @rset = Institution.with_type
    else
      search_term = search_term.to_s.downcase

      clause = ['lower(facility_code) = (?) OR lower(institution) LIKE (?) OR lower(city) LIKE (?)']
      terms = [search_term, "%#{search_term}%", "%#{search_term}%"]

      @rset = Institution.with_type.where(clause + terms)
    end
  end

  # Calculates veteran retention rate adapted from Patrick's JS functions
  #
  def get_veteran_retention_rate
    # If upper class use ba, otherwise use otb
    upper_class = [3, 4].include?(pred_degree_awarded) || offers_4_year?

    rate = if upper_class
             retention_rate_veteran_ba.present? ? retention_rate_veteran_ba : retention_rate_veteran_otb
           else
             retention_rate_veteran_otb.present? ? retention_rate_veteran_otb : retention_rate_veteran_ba
           end

    rate
  end

  # Calculates all students retention rate adapted from Patrick's JS functions
  #
  def get_all_student_retention_rate
    # If upper class use ba, otherwise use otb
    upper_class = [3, 4].include?(pred_degree_awarded) || offers_4_year?

    rate = if upper_class
             retention_all_students_ba.present? ? retention_all_students_ba : retention_all_students_otb
           else
             retention_all_students_otb.present? ? retention_all_students_otb : retention_all_students_ba
           end

    rate
  end

  # Returns the highest degree offered.
  #
  def highest_degree
    DEGREES[pred_degree_awarded] || DEGREES[va_highest_degree_downcased] || 'No Data'
  end

  private

  def offers_4_year?
    va_highest_degree_downcased == '4-year'
  end

  def va_highest_degree_downcased
    va_highest_degree_offered.try(:downcase)
  end
end
