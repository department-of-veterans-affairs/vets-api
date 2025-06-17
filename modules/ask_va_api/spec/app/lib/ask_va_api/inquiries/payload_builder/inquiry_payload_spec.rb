# frozen_string_literal: true

require 'rails_helper'
require AskVAApi::Engine.root.join('spec', 'support', 'shared_contexts.rb')

RSpec.describe AskVAApi::Inquiries::PayloadBuilder::InquiryPayload do
  subject(:builder) { described_class.new(inquiry_params: params, user: authorized_user) }

  # allow to have access to inquiry_params and translated_payload
  include_context 'shared data'

  let(:cache_data_service) { instance_double(Crm::CacheData) }
  let(:authorized_user) { build(:user, :accountable_with_sec_id, icn: '234', edipi: '123') }
  let(:cached_data) do
    data = File.read('modules/ask_va_api/config/locales/get_optionset_mock_data.json')
    JSON.parse(data, symbolize_names: true)
  end

  let(:patsr_facilities) do
    data = File.read('modules/ask_va_api/config/locales/get_facilities_mock_data.json')
    JSON.parse(data, symbolize_names: true)
  end

  before do
    allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
    allow(cache_data_service).to receive(:call).with(
      endpoint: 'optionset',
      cache_key: 'optionset'
    ).and_return(cached_data)
    allow(cache_data_service).to receive(:fetch_and_cache_data).and_return(patsr_facilities)
  end

  describe '#call' do
    let(:params) { inquiry_params[:inquiry] }

    context 'when inquiry_params is received' do
      it 'builds the correct payload' do
        expect(builder.call).to eq(translated_payload)
      end
    end

    context 'when your_health_facility is nil' do
      let(:params) { i_am_veteran_edu[:inquiry] }

      it 'returns nil for medical center' do
        response = builder.call

        expect(response[:MedicalCenter]).to be_nil
      end
    end

    context "when there's no user" do
      let(:authorized_user) { nil }

      it 'set LevelOfAuthentication to Unauthenticated' do
        expect(builder.call[:LevelOfAuthentication]).to eq('722310000')
      end
    end

    context 'when no params are passed' do
      let(:params) { nil }

      it 'raise an error' do
        expect { builder.call }.to raise_error(
          AskVAApi::Inquiries::PayloadBuilder::InquiryPayload::InquiryPayloadError
        )
      end
    end

    context 'when your_location_of_residence is passed' do
      let(:params) do
        {
          category_id: '75524deb-d864-eb11-bb24-000d3a579c45',
          contact_preference: 'Email',
          email_address: 'test@test.com',
          phone_number: '3039751100',
          question: 'test',
          relationship_to_veteran: "I'm the Veteran",
          select_category: 'Education benefits and work study',
          select_topic: 'Veteran Readiness and Employment (Chapter 31)',
          subject: 'test',
          topic_id: 'b18831a7-8276-ef11-a671-001dd8097cca',
          who_is_your_question_about: 'Myself',
          your_location_of_residence: 'Colorado',
          your_vre_information: false,
          address: {
            military_address: {
              military_post_office: nil,
              military_state: nil
            }
          },
          about_yourself: {
            date_of_birth: '1950-01-01',
            first: 'Submitter',
            last: 'SubVet',
            social_or_service_num: {
              ssn: '123456799'
            }
          },
          about_the_veteran: {
            social_or_service_num: {}
          },
          about_the_family_member: {
            social_or_service_num: {}
          },
          state_or_residency: {},
          files: [
            {
              file_name: nil,
              file_content: nil
            }
          ],
          school_obj: {}
        }
      end

      it 'raise an error' do
        expect(builder.call[:SubmitterStateOfResidency]).to eq({ Name: 'Colorado', StateCode: 'CO' })
      end
    end

    context 'when counselor field is present' do
      let(:params) { veteran_spouse_edu_vrae_flow[:inquiry] }

      it 'includes the counselor value in the payload' do
        result = builder.call

        # Adjust this line based on how and where counselor is mapped in your payload
        expect(result[:WhoWasTheirCounselor]).to eq('Joe Smith')
      end
    end
  end
end
