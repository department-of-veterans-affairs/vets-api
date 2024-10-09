# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::OptionsetDataJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:cache_data_instance) { instance_double(Crm::CacheData) }
    let(:option_keys) do
      %w[inquiryabout inquirysource inquirytype levelofauthentication suffix veteranrelationship
         dependentrelationship responsetype]
    end
    let(:cache_data) do
      lambda do |option|
        {
          'inquiryabout' => { Data: [{ Id: 722_310_003, Name: 'A general question' },
                                     { Id: 722_310_000, Name: 'About Me, the Veteran' },
                                     { Id: 722_310_002, Name: 'For the dependent of a Veteran' },
                                     { Id: 722_310_001, Name: 'On behalf of a Veteran' }] },
          'inquirysource' => { Data: [{ Id: 722_310_005, Name: 'Phone' },
                                      { Id: 722_310_004, Name: 'US Mail' },
                                      { Id: 722_310_000, Name: 'AVA' },
                                      { Id: 722_310_001, Name: 'Email' },
                                      { Id: 722_310_002, Name: 'Facebook' }] },
          'inquirytype' => { Data: [{ Id: 722_310_000, Name: 'Compliment' },
                                    { Id: 722_310_001, Name: 'Question' },
                                    { Id: 722_310_002, Name: 'Service Complaint' },
                                    { Id: 722_310_006, Name: 'Suggestion' },
                                    { Id: 722_310_004, Name: 'Other' }] },
          'levelofauthentication' => { Data: [{ Id: 722_310_002, Name: 'Authenticated' },
                                              { Id: 722_310_000, Name: 'Unauthenticated' },
                                              { Id: 722_310_001, Name: 'Personal' },
                                              { Id: 722_310_003, Name: 'Business' }] },
          'suffix' => { Data: [{ Id: 722_310_000, Name: 'Jr' },
                               { Id: 722_310_001, Name: 'Sr' },
                               { Id: 722_310_003, Name: 'II' },
                               { Id: 722_310_004, Name: 'III' },
                               { Id: 722_310_006, Name: 'IV' },
                               { Id: 722_310_002, Name: 'V' },
                               { Id: 722_310_005, Name: 'VI' }] },
          'veteranrelationship' => { Data: [{ Id: 722_310_007, Name: 'Child' },
                                            { Id: 722_310_008, Name: 'Guardian' },
                                            { Id: 722_310_005, Name: 'Parent' },
                                            { Id: 722_310_012, Name: 'Sibling' },
                                            { Id: 722_310_015, Name: 'Spouse/Surviving Spouse' },
                                            { Id: 722_310_004, Name: 'Ex-spouse' },
                                            { Id: 722_310_010, Name: 'GI Bill Beneficiary' },
                                            { Id: 722_310_018, Name: 'Other (Personal)' },
                                            { Id: 722_310_000, Name: 'Attorney' },
                                            { Id: 722_310_001, Name: 'Authorized 3rd Party' },
                                            { Id: 722_310_020, Name: 'Fiduciary' },
                                            { Id: 722_310_006, Name: 'Funeral Director' },
                                            { Id: 722_310_016, Name: 'OJT/Apprenticeship Supervisor' },
                                            { Id: 722_310_013, Name: 'School Certifying Official' },
                                            { Id: 722_310_019, Name: 'VA Employee' },
                                            { Id: 722_310_017, Name: 'VSO' },
                                            { Id: 722_310_014, Name: 'Work Study Site Supervisor' },
                                            { Id: 722_310_011, Name: 'Other (Business)' },
                                            { Id: 722_310_002, Name: 'School Official (DO NOT USE)' },
                                            { Id: 722_310_009, Name: 'Helpless Child' },
                                            { Id: 722_310_003, Name: 'Dependent Child' }] },
          'dependentrelationship' => { Data: [{ Id: 722_310_006, Name: 'Child' },
                                              { Id: 722_310_009, Name: 'Parent' },
                                              { Id: 722_310_008, Name: 'Spouse' },
                                              { Id: 722_310_010, Name: 'Stepchild' },
                                              { Id: 722_310_005, Name: 'Other' }] },
          'responsetype' => { Data: [{ Id: 722_310_000, Name: 'Email' }, { Id: 722_310_001, Name: 'Phone' },
                                     { Id: 722_310_002, Name: 'US Mail' }] }
        }[option]
      end
    end

    context 'when successful' do
      before do
        allow(Crm::CacheData).to receive(:new).and_return(cache_data_instance)
        option_keys.each do |option|
          allow(cache_data_instance).to receive(:fetch_and_cache_data).with(
            endpoint: 'optionset',
            cache_key: option,
            payload: { name: "iris_#{option}" }
          ).and_return(cache_data.call(option))
        end
      end

      it 'creates an instance of Crm::CacheData for each option and calls it' do
        described_class.new.perform

        %w[
          inquiryabout inquirysource inquirytype levelofauthentication
          suffix veteranrelationship dependentrelationship responsetype
        ].each do |option|
          expect(cache_data_instance).to have_received(:fetch_and_cache_data).with(
            endpoint: 'optionset',
            cache_key: option,
            payload: { name: "iris_#{option}" }
          )
        end

        expect(cache_data_instance).to have_received(:fetch_and_cache_data).exactly(8).times
      end
    end

    context 'when an error occurs during caching' do
      let(:logger) { instance_double(LogService) }
      let(:body) do
        '{"Data":null,"Message":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
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
        allow_any_instance_of(Crm::Service).to receive(:call).and_return(failure)
        allow(LogService).to receive(:new).and_return(logger)
        allow(logger).to receive(:call)
      end

      it 'logs the error and continues processing when an error occurs' do
        described_class.new.perform

        expect(logger).to have_received(:call).exactly(8).times
      end
    end
  end
end
