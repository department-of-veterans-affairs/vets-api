# frozen_string_literal: true

require 'sidekiq'

module Veteran
  class BaseReloader
    include Sidekiq::Job
    BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'
    USER_TYPE_ATTORNEY = 'attorney'
    USER_TYPE_CLAIM_AGENT = 'claim_agents'
    USER_TYPE_VSO = 'veteran_service_officer'

    private

    def find_or_initialize_by_id(hash_object, user_type)
      rep = Veteran::Service::Representative.find_or_initialize_by(
        representative_id: hash_object['Registration Num']
      )

      rep.poa_codes  ||= []
      rep.user_types ||= []

      poa_code = hash_object['POA Code']&.gsub(/\W/, '')
      rep.poa_codes << poa_code if poa_code.present? && rep.poa_codes.exclude?(poa_code)
      rep.user_types << user_type unless rep.user_types.include?(user_type)

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
  end
end
