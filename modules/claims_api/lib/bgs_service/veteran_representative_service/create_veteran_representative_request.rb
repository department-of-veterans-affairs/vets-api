# frozen_string_literal: true

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    def create_veteran_representative(options)
      injected = convert_nil_values(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <data:VeteranRepresentative>
          #{injected}
        </data:VeteranRepresentative>
      EOXML

      make_request(
        namespace: 'data',
        action: 'createVeteranRepresentative',
        body: body.to_s,
        key: 'VeteranRepresentativeReturn'
      )
    end
  end
end
