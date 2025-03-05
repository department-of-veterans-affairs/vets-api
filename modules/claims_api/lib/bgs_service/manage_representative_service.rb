# frozen_string_literal: true

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    ALL_STATUSES = %w[NEW ACCEPTED DECLINED].freeze

    def bean_name
      'VDC/ManageRepresentativeService'
    end

    def read_poa_request(poa_codes: [], page_size: nil, page_index: nil, filter: {}, use_mocks: false) # rubocop:disable Metrics/MethodLength
      # Workaround to allow multiple roots in the Nokogiri XML builder
      # https://stackoverflow.com/a/4907450
      doc = Nokogiri::XML::DocumentFragment.parse ''

      status_list = filter['status'].presence || ALL_STATUSES
      state = filter['state']
      city = filter['city']
      country = filter['country']

      Nokogiri::XML::Builder.with(doc) do |xml|
        xml.send('data:POACodeList') do
          poa_codes.each do |poa_code|
            xml.POACode poa_code
          end
        end
        xml.send('data:SecondaryStatusList') do
          status_list.each do |status|
            xml.SecondaryStatus status
          end
        end
        if state
          xml.send('data:StateList') do
            xml.State state
          end
        end
        if city
          xml.send('data:CityList') do
            xml.City city
          end
        end
        if country
          xml.send('data:CountryList') do
            xml.Country country
          end
        end
        if page_size || page_index
          xml.send('data:POARequestParameter') do
            xml.pageSize page_size if page_size
            xml.pageIndex page_index if page_index
          end
        end
      end

      body = builder_to_xml(doc)

      make_request(endpoint: bean_name, action: 'readPOARequest', body:, key: 'POARequestRespondReturnVO',
                   namespaces: { 'data' => '/data' }, transform_response: false, use_mocks:)
    end

    def read_poa_request_by_ptcpnt_id(ptcpnt_id:)
      builder = Nokogiri::XML::Builder.new do
        PtcpntId ptcpnt_id
      end

      body = builder_to_xml(builder)

      make_request(endpoint: bean_name, action: 'readPOARequestByPtcpntId', body:, key: 'POARequestRespondReturnVO',
                   namespaces: { 'data' => '/data' }, transform_response: false)
    end

    def update_poa_request(proc_id:, representative: {}, secondary_status: 'obsolete', declined_reason: nil)
      first_name = representative[:first_name].presence || 'vets-api'
      last_name = representative[:last_name].presence || 'vets-api'

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send('data:POARequestUpdate') do
          xml.VSOUserFirstName first_name
          xml.VSOUserLastName last_name
          xml.dateRequestActioned Time.current.iso8601
          xml.procId proc_id
          xml.secondaryStatus secondary_status
          xml.declinedReason declined_reason if declined_reason
        end
      end

      body = builder_to_xml(builder)

      make_request(endpoint: bean_name, action: 'updatePOARequest', body:, key: 'POARequestUpdate',
                   namespaces: { 'data' => '/data' }, transform_response: false)
    end

    def update_poa_relationship(pctpnt_id:, file_number:, ssn:, poa_code:)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send('data:POARelationship') do
          xml.dateRequestAccepted Time.current.iso8601
          xml.vetPtcpntId pctpnt_id
          xml.vetFileNumber file_number
          xml.vetSSN ssn
          xml.vsoPOACode poa_code
        end
      end

      body = builder_to_xml(builder)

      make_request(endpoint: bean_name, action: 'updatePOARelationship', body:, key: 'POARelationshipReturnVO',
                   namespaces: { 'data' => '/data' }, transform_response: false)
    end
  end
end
