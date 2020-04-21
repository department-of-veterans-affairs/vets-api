# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V1::FHIRService do
  subject { VAOS::V1::FHIRService.new(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#make_request' do
    context 'with an invalid http method' do
      it 'raises a no method error' do
        expect { subject.make_request(:let, 'Organization/353830') }.to raise_error(
          NoMethodError
        )
      end
    end

    context 'when VAMF returns a 404' do
      it 'raises a backend exception with key VAOS_404' do
        VCR.use_cassette('vaos/fhir/404', match_requests_on: %i[method uri]) do
          expect { subject.make_request(:get, 'MissingResource') }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) { |e| expect(e.key).to eq('VAOS_404') }
        end
      end
    end

    context 'with valid args' do
      it 'returns the JSON response body from the VAMF response' do
        VCR.use_cassette('vaos/fhir/get_organization', match_requests_on: %i[method uri]) do
          response = subject.make_request(:get, 'Organization/353830')
          expect(JSON.parse(response.body)).to eq(
            {
              'resourceType' => 'Organization',
              'id' => '353830',
              'text' => {
                'status' => 'generated',
                'div' => '<div xmlns="http://www.w3.org/1999/xhtml"><!--    <div class="hapiHeaderText" ' \
                  'th:narrative="${resource.name}"></div>-->' \
                  '<table class="hapiPropertyTable"><tbody><tr><td>Identifier</td><td>580</td></tr><tr>' \
                  '<td>Address</td><td><span>2002 Holcombe Blvd. ' \
                  '</span><br/><span>Houston </span><span>TX </span></td></tr></tbody></table></div>'
              },
              'identifier' => [
                { 'system' => 'urn:oid:2.16.840.1.113883.6.233', 'value' => '580' }
              ],
              'active' => true,
              'name' => 'HOUSTON VAMC',
              'address' => [
                {
                  'line' => ['2002 Holcombe Blvd.'],
                  'city' => 'Houston',
                  'state' => 'TX',
                  'postalCode' => '77030-4298'
                }
              ]
            }
          )
        end
      end
    end
  end
end
