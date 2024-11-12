# frozen_string_literal: true

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    def bean_name
      'VDC/ManageRepresentativeService'
    end

    def read_poa_request(poa_codes: [], page_size: nil, page_index: nil) # rubocop:disable Metrics/MethodLength
      # Workaround to allow multiple roots in the Nokogiri XML builder
      # https://stackoverflow.com/a/4907450
      doc = Nokogiri::XML::DocumentFragment.parse ''

      Nokogiri::XML::Builder.with(doc) do |xml|
        xml.send('data:POACodeList') do
          poa_codes.each do |poa_code|
            xml.POACode poa_code
          end
        end
        xml.send('data:SecondaryStatusList') do
          %w[New Pending Accepted Declined].each do |status|
            xml.SecondaryStatus status
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
  end
end
