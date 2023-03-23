# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'paginated request from params with expected IDs' do |request_params, ids, mobile = nil|
  let(:params) { request_params }

  context request_params do
    before do
      get '/v1/facilities/va', params:
    end

    it { expect(response).to be_successful }

    it "is expected to contain ids: #{ids}" do
      expect(parsed_body['data'].collect { |x| x['id'] }).to match(ids)
    end

    unless mobile.nil?
      it "is expected that all results have mobile=#{mobile}" do
        expected_array = ids.collect { |id| { id:, mobile: } }
        expect(parsed_body['data'].collect { |x| x['attributes'].slice(:id, :mobile) }).to match(expected_array)
      end
    end

    it 'is expected to have specified pagination metadata' do
      current_page = request_params[:page] || 1
      prev_page = current_page > 1 ? current_page - 1 : nil
      expect(parsed_body[:meta][:pagination]).to include({
                                                           current_page:,
                                                           prev_page:,
                                                           next_page: be_kind_of(Integer).or(be_nil),
                                                           total_pages: be_kind_of(Integer)
                                                         })
    end

    it 'is expected to include pagination links' do
      current_page = parsed_body[:meta][:pagination][:current_page]
      prev_page = parsed_body[:meta][:pagination][:prev_page]
      next_page = parsed_body[:meta][:pagination][:next_page]
      last_page = parsed_body[:meta][:pagination][:total_pages]

      prev_params = params.merge({ page: prev_page, per_page: 10 }).to_query
      next_params = params.merge({ page: next_page, per_page: 10 }).to_query

      prev_link = prev_page ? "http://www.example.com/v1/facilities/va?#{prev_params}" : nil
      next_link = next_page ? "http://www.example.com/v1/facilities/va?#{next_params}" : nil

      expect(parsed_body[:links]).to match(
        self: "http://www.example.com/v1/facilities/va?#{params.merge({ page: current_page, per_page: 10 }).to_query}",
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

RSpec.describe 'V1::Facilities::Va', team: :facilities, vcr: vcr_options do
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
                      bbox: [-74.730, 40.015, -73.231, 41.515],
                      page: 2
                    },
                    %w[
                      vc_0102V vc_0857MVC vc_0110V nca_808 nca_947
                      vha_526 vha_526QA vc_0109V vha_561GD vc_0132V
                    ]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64]
                    },
                    %w[
                      vba_348e vha_648GI vba_348 vba_348a vc_0617V
                      vba_348d vha_648 vba_348h vha_648A4 nca_954
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

    context 'params[:exclude_mobile]' do
      context 'true' do
        it_behaves_like 'paginated request from params with expected IDs',
                        {
                          exclude_mobile: true,
                          bbox: [-74.730, 40.015, -73.231, 41.515],
                          page: 1
                        },
                        %w[
                          vba_306h vba_306i vha_630 vba_306 vha_630GA
                          vc_0133V vha_526GD vc_0106V vc_0105V vha_561GE
                        ]
      end
    end

    context 'params[:mobile]' do
      context 'mobile not passed' do
        it_behaves_like 'paginated request from params with expected IDs',
                        {
                          bbox: [-74.730, 40.015, -73.231, 41.515],
                          page: 1
                        },
                        %w[
                          vba_306h vba_306i vha_630 vba_306 vha_630GA
                          vc_0133V vha_526GD vc_0106V vc_0105V vha_561GE
                        ]
      end

      context 'true' do
        it_behaves_like 'paginated request from params with expected IDs',
                        {
                          mobile: true,
                          bbox: [-74.730, 40.015, -73.231, 41.515],
                          page: 1
                        },
                        %w[
                          vc_0857MVC vha_526QA vha_630QA vha_630QB
                          vha_620QA vha_620QC vha_632QA vha_632QB
                        ],
                        true
      end

      context 'false' do
        it_behaves_like 'paginated request from params with expected IDs',
                        {
                          mobile: false,
                          bbox: [-74.730, 40.015, -73.231, 41.515],
                          page: 1
                        },
                        %w[
                          vha_630 vha_630GA vc_0133V vha_526GD vc_0106V
                          vc_0105V vha_561GE vc_0102V vc_0110V vha_526
                        ],
                        false
      end
    end
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
                  { service: 'Audiology',        new: 30.792207, established: 32.107981 },
                  { service: 'Dermatology',      new: 17.095238, established: 56.152542 },
                  { service: 'MentalHealthCare', new: 14.083333, established: 1.885372 },
                  { service: 'Ophthalmology',    new: 33.0,      established: 6.691056 },
                  { service: 'Optometry',        new: 46.035087, established: 43.350537 },
                  { service: 'PrimaryCare',      new: 9.394957,  established: 7.711797 },
                  { service: 'SpecialtyCare',    new: 24.126666, established: 23.555555 }
                ],
                effectiveDate: '2021-04-05'

              },
              activeStatus: 'A',
              address: {
                mailing: {},
                physical: {
                  zip: '98661-3753',
                  city: 'Vancouver',
                  state: 'WA',
                  address1: '1601 East 4th Plain Boulevard',
                  address2: nil,
                  address3: nil
                }
              },
              classification: 'VA Medical Center (VAMC)',
              detailedServices: nil,
              facilityType: 'va_health_facility',
              feedback: {
                health: {
                  primaryCareUrgent: 0.7699999809265137,
                  primaryCareRoutine: 0.8500000238418579
                },
                effectiveDate: '2021-03-05'
              },
              hours: {
                monday: '730AM-430PM',
                tuesday: '730AM-430PM',
                wednesday: '730AM-430PM',
                thursday: '730AM-430PM',
                friday: '730AM-430PM',
                saturday: 'Closed',
                sunday: 'Closed'
              },
              id: 'vha_648A4',
              lat: 45.63938186,
              long: -122.65538544,
              mobile: false,
              name: 'Portland VA Medical Center-Vancouver',
              operatingStatus: {
                code: 'NORMAL'
              },
              operationalHoursSpecialInstructions: 'Expanded or Nontraditional hours are available for some ' \
                                                   'services on a routine and or requested basis. Please call our ' \
                                                   'main phone number for details. |',
              phone: {
                fax: '360-690-0864',
                main: '360-759-1901',
                pharmacy: '503-273-5183',
                afterHours: '360-696-4061',
                patientAdvocate: '503-273-5308',
                mentalHealthClinic: '503-273-5187',
                enrollmentCoordinator: '503-273-5069'
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
                lastUpdated: '2021-04-05'
              },
              uniqueId: '648A4',
              visn: '20',
              website: 'https://www.portland.va.gov/locations/vancouver.asp'
            }
          }
        }
      )
    end
  end
end
