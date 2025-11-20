# frozen_string_literal: true

module SSOe
  class GetSSOeTraitsByCspidMessage
    attr_reader :credential_method,
                :credential_id,
                :first_name,
                :last_name,
                :birth_date,
                :ssn,
                :email,
                :phone,
                :street1,
                :city,
                :state,
                :zipcode

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      credential_method:,
      credential_id:,
      first_name:,
      last_name:,
      birth_date:,
      ssn:,
      email:,
      phone:,
      street1:,
      city:,
      state:,
      zipcode:
    )
      @credential_method = credential_method
      @credential_id     = credential_id
      @first_name        = first_name
      @last_name         = last_name
      @birth_date        = birth_date
      @ssn               = ssn
      @email             = email
      @phone             = phone
      @street1           = street1
      @city              = city
      @state             = state
      @zipcode           = zipcode
    end
    # rubocop:enable Metrics/ParameterLists

    def perform
      <<~XML
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ws="http://ws.ssoe.acs">
          <soapenv:Header/>
          <soapenv:Body>
            <ws:getSSOeTraitsByCSPID>
              <ws:cspid>#{full_credential_id}</ws:cspid>
              <ws:firstname>#{first_name}</ws:firstname>
              <ws:lastname>#{last_name}</ws:lastname>
              <ws:email>#{email}</ws:email>
              <ws:uid>#{credential_id}</ws:uid>
              <ws:cspbirthDate>#{birth_date}</ws:cspbirthDate>
              <ws:versioncode>#{version_code}</ws:versioncode>
              <ws:pnid>#{ssn}</ws:pnid>
              <ws:authenticationMethod>#{authentication_method}</ws:authenticationMethod>
              <ws:credAssuranceLevel>#{credential_assurance_level}</ws:credAssuranceLevel>
              <ws:ial>#{ial}</ws:ial>
              <ws:issueInstant>#{issue_instant}</ws:issueInstant>
              <ws:street1>#{street1}</ws:street1>
              <ws:city>#{city}</ws:city>
              <ws:state>#{state}</ws:state>
              <ws:zipcode>#{zipcode}</ws:zipcode>
              <ws:phone>#{phone}</ws:phone>
              <ws:cspIdentifier>#{credential_identifier}</ws:cspIdentifier>
              <ws:cspMethod>#{credential_method}</ws:cspMethod>
              <ws:proofingAuthority>#{proofing_authority}</ws:proofingAuthority>
            </ws:getSSOeTraitsByCSPID>
          </soapenv:Body>
        </soapenv:Envelope>
      XML
    end

    private

    def full_credential_id
      "#{credential_identifier}_#{credential_id}"
    end

    def issue_instant
      Time.zone.now
    end

    def credential_identifier
      case credential_method
      when 'idme'
        '200VIDM'
      when 'logingov'
        '200VLGN'
      end
    end

    def authentication_method
      'http://idmanagement.gov/ns/assurance/aal/2'
    end

    def ial
      2
    end

    def credential_assurance_level
      3
    end

    def version_code
      '1.0.0'
    end

    def proofing_authority
      'FICAM'
    end
  end
end
