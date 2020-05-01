# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: '/lighthouse/facilities',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.shared_examples 'paginated request from params with expected IDs' do |request_params, ids|
  let(:params) { request_params }
  let(:paginated_params) { params.merge({ page: 1, per_page: 10 }) }

  context request_params do
    before do
      get '/v0/facilities/va', params: params
    end

    it { expect(response).to be_successful }

    it "is expected to contain ids: #{ids}" do
      expect(parsed_body['data'].collect { |x| x['id'] }).to match(ids)
    end

    it 'is expected to include pagination metadata' do
      expect(parsed_body[:meta]).to match(
        pagination: {
          current_page: a_kind_of(Integer),
          per_page: a_kind_of(Integer),
          total_entries: a_kind_of(Integer),
          total_pages: a_kind_of(Integer)
        }
      )
    end

    it 'is expected to include pagination links' do
      expect(parsed_body[:links]).to match(
        self: "http://www.example.com/v0/facilities/va?#{params.to_query}",
        first: "http://www.example.com/v0/facilities/va?#{paginated_params.to_query}",
        prev: nil,
        next: nil,
        last: "http://www.example.com/v0/facilities/va?#{paginated_params.to_query}"
      )
    end
  end
end

RSpec.describe 'VA Facilities Locator - Lighthouse', type: :request, team: :facilities, vcr: vcr_options do
  include SchemaMatchers

  subject(:parsed_body) { JSON.parse(response.body).with_indifferent_access }

  before do
    Flipper.enable(:facility_locator_pull_operating_status_from_lighthouse, false)
    Flipper.enable(:facility_locator_lighthouse_api, true)
  end

  describe 'GET #index' do
    it 'returns 400 for invalid type parameter' do
      get '/v0/facilities/va', params: { type: 'bogus' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for query with services but no type' do
      get '/v0/facilities/va', params: { services: 'EyeCare' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for health query with unknown service' do
      get '/v0/facilities/va', params: { type: 'health', services: ['OilChange'] }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for benefits query with unknown service' do
      get '/v0/facilities/va', params: { type: 'benefits', services: ['Haircut'] }
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
        get '/v0/facilities/va', params: {bbox: [-122.786758, 45.451913, -122.440689, 45.64]}
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
                    ['vba_348']

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
  end

  describe 'GET #show' do
    before do
      get '/v0/facilities/va/vha_648A4'
    end

    it { expect(response).to be_successful }

    it do
      expect(subject).to match(
        {
          data: {
            id: 'vha_648A4',
            type: 'va_facilities',
            attributes: {
              access: {
                health: {
                  audiology: { new: 5.5, established: nil },
                  dermatology: { new: 4.25, established: 10.0 },
                  mentalhealthcare: { new: 13.714285, established: 2.497297 },
                  ophthalmology: { new: nil, established: 0.764705 },
                  optometry: { new: 0.8, established: 1.347826 },
                  primary_care: { new: 5.12, established: 1.289215 },
                  specialtycare: { new: 4.76, established: 3.416666 },
                  effective_date: '2020-04-13'
                }
              },
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
                  effective_date: '2019-06-20',
                  primary_care_urgent: 0.8500000238418579,
                  primary_care_routine: 0.8899999856948853
                }
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
              lat: 45.63942553000004,
              long: -122.65533567999995,
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
                health: [
                  {
                    sl1: ['Audiology'],
                    sl2: []
                  },
                  {
                    sl1: ['DentalServices'],
                    sl2: []
                  },
                  {
                    sl1: ['Dermatology'],
                    sl2: []
                  },
                  {
                    sl1: ['EmergencyCare'],
                    sl2: []
                  },
                  {
                    sl1: ['MentalHealthCare'],
                    sl2: []
                  },
                  {
                    sl1: ['Nutrition'],
                    sl2: []
                  },
                  {
                    sl1: ['Ophthalmology'],
                    sl2: []
                  },
                  {
                    sl1: ['Optometry'],
                    sl2: []
                  },
                  {
                    sl1: ['Podiatry'],
                    sl2: []
                  },
                  {
                    sl1: ['PrimaryCare'],
                    sl2: []
                  },
                  {
                    sl1: ['SpecialtyCare'],
                    sl2: []
                  }
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
