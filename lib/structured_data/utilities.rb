# frozen_string_literal: true

module StructuredData
  class Utilities
    def self.find_dependents(file_number_or_ssn)
      service = LighthouseBGS::Services.new(external_uid: 0, external_key: 'VA.gov')
      service.people.find_dependents(file_number_or_ssn).fetch(:dependent, nil)
    end

    def self.find_dependent_claimant(veteran, c_name, _c_address)
      results = find_dependents(
        veteran.participant_id
      )

      children = results[:dependent].select do |c|
        [
          c[:ptcpnt_rlnshp_type_nm] == 'Child',
          c[:first_nm].downcase == c_name['first'].downcase,
          c[:last_nm].downcase == c_name['last'].downcase
        ].reduce(&:&)
      end

      children.first
    end
  end
end
