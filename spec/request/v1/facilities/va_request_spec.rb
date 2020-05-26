# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'paginated request from params with expected IDs' do |request_params, ids|
  let(:params) { request_params }

  context request_params do
    before do
      get '/v1/facilities/va', params: params
    end

    it { expect(response).to be_successful }

    it "is expected to contain ids: #{ids}" do
      expect(parsed_body['data'].collect { |x| x['id'] }).to match(ids)
    end

    context 'pagination metadata' do
      subject { parsed_body[:meta][:pagination] }

      it { is_expected.to have_key('current_page') }
      it { is_expected.to have_key('prev_page') }
      it { is_expected.to have_key('next_page') }
      it { is_expected.to have_key('total_pages') }
    end

    it 'is expected to include pagination links' do
      prev_page = parsed_body[:meta][:pagination][:prev_page]
      next_page = parsed_body[:meta][:pagination][:next_page]
      last_page = parsed_body[:meta][:pagination][:total_pages]

      prev_params = params.merge({ page: prev_page, per_page: 10 }).to_query
      next_params = params.merge({ page: next_page, per_page: 10 }).to_query

      prev_link = prev_page ? "http://www.example.com/v1/facilities/va?#{prev_params}" : nil
      next_link = next_page ? "http://www.example.com/v1/facilities/va?#{next_params}" : nil

      expect(parsed_body[:links]).to match(
        self: "http://www.example.com/v1/facilities/va?#{params.merge({ page: 1, per_page: 10 }).to_query}",
        first: "http://www.example.com/v1/facilities/va?#{params.merge({ per_page: 10 }).to_query}",
        prev: prev_link,
        next: next_link,
        last: "http://www.example.com/v1/facilities/va?#{params.merge({ page: last_page, per_page: 10 }).to_query}"
      )
    end
  end
end

vcr_options = {
  cassette_name: '/lighthouse/facilities',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe 'V1::Facilities::Va', type: :request, team: :facilities, vcr: vcr_options do
  include SchemaMatchers

  subject(:parsed_body) { JSON.parse(response.body).with_indifferent_access }

  describe 'GET #index' do
    it 'returns 400 for invalid type parameter' do
      get '/v1/facilities/va', params: { type: 'bogus' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for query with services but no type' do
      get '/v1/facilities/va', params: { services: 'EyeCare' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for health query with unknown service' do
      get '/v1/facilities/va', params: { type: 'health', services: ['OilChange'] }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for benefits query with unknown service' do
      get '/v1/facilities/va', params: { type: 'benefits', services: ['Haircut'] }
      expect(response).to have_http_status(:bad_request)
    end

    it "sends a 'lighthouse.facilities.request.faraday' notification to any subscribers listening" do
      allow(StatsD).to receive(:measure)

      expect(StatsD).to receive(:measure).with(
        'facilities.lighthouse',
        kind_of(Numeric),
        hash_including(
          tags: ['facilities.lighthouse']
        )
      )

      expect do
        get '/v1/facilities/va', params: { bbox: [-122.786758, 45.451913, -122.440689, 45.64] }
      end.to instrument('lighthouse.facilities.request.faraday')
    end

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64]
                    },
                    %w[
                      vba_348e vha_648GI vba_348 vba_348a vc_0617V
                      vba_348d vha_648 vba_348h vha_648A4 nca_907
                    ]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64],
                      type: 'health'
                    },
                    %w[vha_648GI vha_648 vha_648A4 vha_648GE]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64],
                      type: 'benefits'
                    },
                    %w[vba_348e vba_348 vba_348a vba_348d vba_348h]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64],
                      type: 'benefits',
                      services: ['DisabilityClaimAssistance']
                    },
                    %w[vba_348]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      lat: 33.298639,
                      long: -111.789659
                    },
                    %w[
                      vha_644BY vc_0524V vba_345f vba_345g vba_345
                      vha_644QA vc_0517V vha_644GG vha_644 vha_644QB
                    ]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      zip: 85_297
                    },
                    ['vha_644BY']

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      ids: 'vha_442,vha_552,vha_552GB,vha_442GC,vha_442GB,vha_552GA,vha_552GD'
                    },
                    %w[vha_442 vha_552 vha_552GB vha_442GC vha_442GB vha_552GA vha_552GD]
  end

  describe 'GET #show' do
    before do
      get '/v1/facilities/va/vha_648A4'
    end

    it { expect(response).to be_successful }

    it do
      expect(subject).to match(
        {
          data: {
            id: 'vha_648A4',
            type: 'facility',
            attributes: {
              access: {
                health: [
                  { service: 'Audiology',        new: 5.5,       established: nil },
                  { service: 'Dermatology',      new: 4.25,      established: 10.0 },
                  { service: 'MentalHealthCare', new: 13.714285, established: 2.497297 },
                  { service: 'Ophthalmology',    new: nil,       established: 0.764705 },
                  { service: 'Optometry',        new: 0.8,       established: 1.347826 },
                  { service: 'PrimaryCare',      new: 5.12,      established: 1.289215 },
                  { service: 'SpecialtyCare',    new: 4.76,      established: 3.416666 }
                ],
                effective_date: '2020-04-13'
              },
              active_status: 'A',
              address: {
                mailing: {},
                physical: {
                  zip: '98661-3753',
                  city: 'Vancouver',
                  state: 'WA',
                  address_1: '1601 East 4th Plain Boulevard',
                  address_2: nil,
                  address_3: nil
                }
              },
              classification: 'VA Medical Center (VAMC)',
              facility_type: 'va_health_facility',
              feedback: {
                health: {
                  primary_care_urgent: 0.8500000238418579,
                  primary_care_routine: 0.8899999856948853
                },
                effective_date: '2019-06-20'
              },
              hours: {
                monday: '730AM-430PM',
                tuesday: '730AM-630PM',
                wednesday: '730AM-430PM',
                thursday: '730AM-430PM',
                friday: '730AM-430PM',
                saturday: 'Closed',
                sunday: 'Closed'
              },
              id: 'vha_648A4',
              lat: 45.63942553000004,
              long: -122.65533567999995,
              mobile: false,
              name: 'Portland VA Medical Center-Vancouver',
              operating_status: {
                code: 'NORMAL'
              },
              phone: {
                fax: '360-690-0864',
                main: '360-759-1901',
                pharmacy: '503-273-5183',
                after_hours: '360-696-4061',
                patient_advocate: '503-273-5308',
                mental_health_clinic: '503-273-5187',
                enrollment_coordinator: '503-273-5069'
              },
              services: {
                other: [],
                health: %w[
                  Audiology
                  DentalServices
                  Dermatology
                  EmergencyCare
                  MentalHealthCare
                  Nutrition
                  Ophthalmology
                  Optometry
                  Podiatry
                  PrimaryCare
                  SpecialtyCare
                ],
                last_updated: '2020-04-13'
              },
              unique_id: '648A4',
              visn: '20',
              website: 'https://www.portland.va.gov/locations/vancouver.asp'
            }
          }
        }
      )
    end
  end
end
