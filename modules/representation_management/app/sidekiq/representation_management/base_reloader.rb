# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  class BaseReloader
    include Sidekiq::Job
    BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'
    INDIVIDUAL_TYPE_ATTORNEY = 'attorney'
    INDIVIDUAL_TYPE_CLAIM_AGENT = 'claim_agents'
    INDIVIDUAL_TYPE_VSO_REPRESENTATIVE = 'representative'

    private

    def find_or_initialize_by_id(hash_object, individual_type)
      rep = AccreditedIndividual.find_or_initialize_by(
        registration_number: hash_object['Registration Num']
      )

      poa_code = hash_object['POA Code']&.gsub(/\W/, '')
      rep.poa_code = poa_code
      rep.individual_type = individual_type
      rep.ogc_id = ogc_id(hash_object) if rep.ogc_id.blank?
      rep.phone = hash_object['Phone'] if rep.phone.blank?
      rep.first_name = hash_object['First Name'] if rep.first_name.blank?
      rep.last_name = hash_object['Last Name']&.strip if rep.last_name.blank?
      if !hash_object['Middle Initial'].nil? && rep.middle_initial.blank?
        rep.middle_initial = hash_object['Middle Initial']
      end
      rep.city = hash_object['City'] if rep.city.blank?
      rep.state_code = hash_object['State']&.gsub(/\W/, '') if rep.state_code.blank?
      rep.zip_code = hash_object['Zip']&.gsub(/\W/, '') if rep.zip_code.blank?
      rep
    end

    def fetch_data(action)
      page = Faraday.new(url: BASE_URL).post(action, id: 'frmExcelList', name: 'frmExcelList').body
      doc = Nokogiri::HTML(page)
      headers = doc.xpath('//table/tr').first.children.map { |child| child.children.text.scrub }
      doc.xpath('//table/tr').map do |line|
        row = line.children.map { |child| child.children.text.scrub }
        headers.zip(row).to_h.delete_if { |k, _v| k.blank? } unless headers == row
      end.compact.uniq
    end

    def ogc_id(hash_object)
      hash_object['AccrAttorneyId'] || hash_object['AccrClaimAgentId'] || hash_object['AccrRepresentativeId'] || hash_object['VSOID'] # rubocop:disable Layout/LineLength
    end
  end
end
