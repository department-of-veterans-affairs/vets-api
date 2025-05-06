# frozen_string_literal: true

require 'rails_helper'
require 'iam_ssoe_oauth/service'

describe 'IAMSSOeOAuth::Service' do
  subject(:service) { IAMSSOeOAuth::Service.new }

  describe '#post_introspect' do
    context 'with an active user response' do
      let(:response) do
        VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
          service.post_introspect('ypXeAwQedpmAy5xFD2u5')
        end
      end

      it 'includes a icn' do
        expect(response).to include(fediam_mviicn: '1008596379V859838')
      end

      it 'includes a mvi correlation id string' do
        expect(response).to include(
          fediam_gc_id: '1008596379V859838^NI^200M^USVHA^P|796121200^PI^200BRLS^USVBA^A' \
                        '|0000028114^PN^200PROV^USDVA^A|1005079124^NI^200DOD^USDOD^A|32331150^PI^200CORP^USVBA^A' \
                        '|85c50aa76934460c8736f687a6a30546^PN^200VIDM^USDVA^A|2810777^PI^200CORP^USVBA^A' \
                        '|32324397^PI^200CORP^USVBA^A|19798466a4b143748e664482c6b6b81b^PN^200VIDM^USDVA^A' \
                        '|796121200^AN^200CORP^USVBA^'
        )
      end

      it 'includes the users full name' do
        expect(response).to include(given_name: 'GREG', middle_name: 'A', family_name: 'ANDERSON')
      end

      it 'includes the requesting app id' do
        expect(response).to include(aud: 'VAMobile')
      end

      it 'includes the users email' do
        expect(response).to include(fediam_common_name: 'va.api.user+idme.008@gmail.com')
      end
    end

    context 'with an inactive user response' do
      it 'raises an unauthorized error' do
        VCR.use_cassette('iam_ssoe_oauth/introspect_inactive') do
          expect { service.post_introspect('ypXeAwQedpmAy5xFD2u4') }.to raise_error(
            Common::Exceptions::Unauthorized
          )
        end
      end
    end

    context 'with a 500' do
      it 'raises a BackendServiceException' do
        VCR.use_cassette('iam_ssoe_oauth/introspect_500') do
          expect { service.post_introspect('ypXeAwQedpmAy5xFD2u4') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
