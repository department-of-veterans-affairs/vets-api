# frozen_string_literal: true

require 'rails_helper'
require AskVAApi::Engine.root.join('spec', 'support', 'shared_contexts.rb')

RSpec.describe AskVAApi::Translator do
  subject(:translator) { AskVAApi::Translator.new(inquiry_params:) }

  # allow to have access to inquiry_params and optionset_set_cached_data
  include_context 'shared data'

  let(:cache_data_service) { instance_double(Crm::CacheData) }
  let(:option_keys) do
    %w[inquiryabout inquirysource inquirytype levelofauthentication suffix veteranrelationship
       dependentrelationship responsetype]
  end
  let(:result) { subject.call }

  context 'when succesful' do
    before do
      allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)

      option_keys.each do |option|
        allow(cache_data_service).to receive(:call).with(
          endpoint: 'optionset',
          cache_key: option,
          payload: { name: "iris_#{option}" }
        ).and_return(optionset_cached_data.call(option))
        # optionset_cached_data is in include_context 'shared data'
      end
    end

    it 'translates the keys from snake_case to camel_case' do
      expect(result.keys).to eq(translated_payload.keys)
    end

    it 'translates all the option keys from name to id' do
      expect(result[:InquiryAbout]).to eq(translated_payload[:InquiryAbout])
      expect(result[:InquirySource]).to eq(translated_payload[:InquirySource])
      expect(result[:InquiryType]).to eq(translated_payload[:InquiryType])
      expect(result[:LevelOfAuthentication]).to eq(translated_payload[:LevelOfAuthentication])
      expect(result[:Suffix]).to eq(translated_payload[:Suffix])
      expect(result[:VeteranRelationship]).to eq(translated_payload[:VeteranRelationship])
      expect(result[:DependantRelationship]).to eq(translated_payload[:DependantRelationship])
      expect(result[:ResponseType]).to eq(translated_payload[:ResponseType])
    end

    it 'translates inquiry_params to translated payload' do
      expect(result).to eq(translated_payload)
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
        .with(endpoint: 'optionset', payload: { name: 'iris_inquiryabout' }).and_return(failure)
    end

    it 'log to Datadog, when updating option fails' do
      expect { result }.to raise_error(AskVAApi::TranslatorError)
    end
  end
end
