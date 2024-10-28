# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Translator do
  subject(:translator) { AskVAApi::Translator.new }

  let(:cache_data_service) { instance_double(Crm::CacheData) }
  let(:cached_data) do
    { Data: [{ Name: 'iris_suffix',
               ListOfOptions: [{ Id: 722_310_000, Name: 'Jr' },
                               { Id: 722_310_001, Name: 'Sr' },
                               { Id: 722_310_003, Name: 'II' },
                               { Id: 722_310_004, Name: 'III' },
                               { Id: 722_310_006, Name: 'IV' },
                               { Id: 722_310_002, Name: 'V' },
                               { Id: 722_310_005, Name: 'VI' }] }] }
  end
  let(:result) { subject.call('Jr.') }

  context 'when succesful' do
    before do
      allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)

      allow(cache_data_service).to receive(:call).with(
        endpoint: 'optionset',
        cache_key: 'optionset'
      ).and_return(cached_data)
    end

    it 'translates all the option keys from name to id' do
      expect(result).to eq(722_310_000)
    end
  end

  context 'when an error occurs' do
    let(:body) do
      '{"Data":null,"Message":"Data Validation: Invalid OptionSet Name iris_inquiryabou, valid' \
        ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
        ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
        ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","ExceptionOccurred":' \
        'true,"ExceptionMessage":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
        ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
        ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
        ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","MessageId":' \
        '"6dfa81bd-f04a-4f39-88c5-1422d88ed3ff"}'
    end
    let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

    before do
      allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
      allow_any_instance_of(Crm::Service).to receive(:call)
        .with(endpoint: 'optionset', payload: {}).and_return(failure)
    end

    it 'log to Datadog, when updating option fails' do
      expect { result }.to raise_error(AskVAApi::TranslatorError)
    end
  end
end
