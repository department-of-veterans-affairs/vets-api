# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  class BaseReloader
    include Sidekiq::Job
    BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

    private

    def find_or_initialize_by_id(hash_object, individual_type)
      registration_number = hash_object['Registration Num']&.strip

      return build_rep(hash_object, individual_type) if registration_number.blank?

      lock_key = "accredited_individual:#{registration_number}:#{individual_type}"

      AccreditedIndividual.with_advisory_lock(lock_key) do
        rep = build_rep(hash_object, individual_type)

        return yield(rep) if block_given?

        rep
      end
    end

    def build_rep(hash_object, individual_type)
      registration_number = hash_object['Registration Num']&.strip

      rep =
        if registration_number.blank?
          AccreditedIndividual.new(individual_type:)
        else
          AccreditedIndividual.find_or_initialize_by(
            registration_number:,
            individual_type:
          )
        end

      sanitized_poa_code = hash_object['POA Code']&.gsub(/\W/, '')&.strip

      # Avoid wiping out an existing POA code if the scrape returns blank.
      # Only overwrite when the new value is present, or populate when currently blank.
      rep.poa_code = sanitized_poa_code if sanitized_poa_code.present? || rep.poa_code.blank?

      if rep.ogc_id.blank?
        source_ogc_id = ogc_id_from_payload(hash_object, individual_type)
        rep.ogc_id = source_ogc_id.presence || AccreditedIndividual::DUMMY_OGC_ID
      end

      populate_blank_attributes(rep, hash_object)

      rep
    end

    def populate_blank_attributes(rep, hash_object)
      rep.phone = hash_object['Phone'] if rep.phone.blank?
      rep.first_name = hash_object['First Name'] if rep.first_name.blank?
      rep.last_name = hash_object['Last Name']&.strip if rep.last_name.blank?

      if !hash_object['Middle Initial'].nil? && rep.middle_initial.blank?
        rep.middle_initial = hash_object['Middle Initial']
      end

      rep.city = hash_object['City'] if rep.city.blank?
      rep.state_code = hash_object['State']&.gsub(/\W/, '') if rep.state_code.blank?
      rep.zip_code = hash_object['Zip']&.gsub(/\W/, '') if rep.zip_code.blank?
    end

    def ogc_id_from_payload(hash_object, individual_type)
      case individual_type
      when AccreditedIndividual::INDIVIDUAL_TYPE_ATTORNEY
        hash_object['AccrAttorneyId']
      when AccreditedIndividual::INDIVIDUAL_TYPE_CLAIM_AGENT
        hash_object['AccrClaimAgentId']
      when AccreditedIndividual::INDIVIDUAL_TYPE_VSO_REPRESENTATIVE
        hash_object['AccrRepresentativeId']
      end&.strip
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.options.open_timeout = 10
        f.options.timeout = 30
      end
    end

    def fetch_data(action)
      page = connection
             .post(action, id: 'frmExcelList', name: 'frmExcelList')
             .body

      doc = Nokogiri::HTML(page)
      rows = doc.xpath('//table/tr')
      return [] if rows.empty?

      headers = rows.first.children.map { |child| child.children.text.scrub }

      rows.map do |line|
        row = line.children.map { |child| child.children.text.scrub }
        headers.zip(row).to_h.delete_if { |k, _v| k.blank? } unless headers == row
      end.compact.uniq
    end
  end
end
