# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require 'rails_helper'
require 'ssoe/get_ssoe_traits_by_cspid_message'

RSpec.describe SSOe::GetSSOeTraitsByCspidMessage do
  let(:message) do
    described_class.new(
      credential_method: 'idme',
      credential_id: 'abc123',
      first_name: 'John',
      last_name: 'Doe',
      birth_date: '19800101',
      ssn: '123456789',
      email: 'john.doe@example.com',
      phone: '555-555-5555',
      street1: '123 Main St',
      city: 'Anytown',
      state: 'VA',
      zipcode: '12345'
    )
  end

  describe '#perform' do
    it 'generates the correct SOAP request XML' do
      xml = message.perform

      expect(xml).to include('<ws:cspid>200VIDM_abc123</ws:cspid>')
      expect(xml).to include('<ws:firstname>John</ws:firstname>')
      expect(xml).to include('<ws:lastname>Doe</ws:lastname>')
      expect(xml).to include('<ws:email>john.doe@example.com</ws:email>')
      expect(xml).to include('<ws:uid>abc123</ws:uid>')
      expect(xml).to include('<ws:cspbirthDate>19800101</ws:cspbirthDate>')
      expect(xml).to include('<ws:pnid>123456789</ws:pnid>')
      expect(xml).to include('<ws:authenticationMethod>http://idmanagement.gov/ns/assurance/aal/2</ws:authenticationMethod>')
      expect(xml).to include('<ws:credAssuranceLevel>3</ws:credAssuranceLevel>')
      expect(xml).to include('<ws:ial>2</ws:ial>')
      expect(xml).to include('<ws:street1>123 Main St</ws:street1>')
      expect(xml).to include('<ws:state>VA</ws:state>')
      expect(xml).to include('<ws:proofingAuthority>FICAM</ws:proofingAuthority>')
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
