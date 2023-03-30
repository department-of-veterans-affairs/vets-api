# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'paginated request from params with expected IDs' do
  |request_params, ids, distances = [], mobile = nil|
  let(:params) { request_params }

  let(:request_host) { 'http://www.example.com' }

  context request_params do
    before do
      get '/facilities_api/v1/va', params:
    end

    it { expect(response).to be_successful }

    it "is expected to contain ids: #{ids}" do
      expect(parsed_body['data'].collect { |x| x['id'] }).to match(ids)
    end

    if distances.any?
      it 'each response is expected to have a distance' do
        expected_array = ids.collect.with_index { |id, i| { id:, distance: distances[i] } }
        expect(parsed_body['data'].collect { |x| x['attributes'].slice(:id, :distance) }).to match(expected_array)
      end
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
      expect(parsed_body[:meta][:pagination]).to match({
                                                         current_page:,
                                                         prev_page:,
                                                         next_page: be_kind_of(Integer).or(be_nil),
                                                         total_pages: be_kind_of(Integer),
                                                         total_entries: be_kind_of(Integer)
                                                       })
    end

    it 'is expected to include pagination links' do
      current_page = parsed_body[:meta][:pagination][:current_page]
      prev_page = parsed_body[:meta][:pagination][:prev_page]
      next_page = parsed_body[:meta][:pagination][:next_page]
      last_page = parsed_body[:meta][:pagination][:total_pages]

      prev_params = params.merge({ page: prev_page, per_page: 10 }).to_query
      next_params = params.merge({ page: next_page, per_page: 10 }).to_query

      prev_link = prev_page ? "#{request_host}/facilities_api/v1/va?#{prev_params}" : nil
      next_link = next_page ? "#{request_host}/facilities_api/v1/va?#{next_params}" : nil

      expect(parsed_body[:links]).to match(
        self: "#{request_host}/facilities_api/v1/va?#{params.merge({ page: current_page,
                                                                     per_page: 10 }).to_query}",
        first: "#{request_host}/facilities_api/v1/va?#{params.merge({ per_page: 10 }).to_query}",
        prev: prev_link,
        next: next_link,
        last: "#{request_host}/facilities_api/v1/va?#{params.merge({ page: last_page, per_page: 10 }).to_query}"
      )
    end
  end
end

vcr_options = {
  cassette_name: '/facilities/va/lighthouse',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe 'FacilitiesApi::V1::Va', type: :request, team: :facilities, vcr: vcr_options do
  subject(:parsed_body) { JSON.parse(response.body).with_indifferent_access }

  before(:all) do
    get facilities_api.v1_va_index_url
  end

  describe 'GET #index' do
    it 'returns 400 for invalid type parameter' do
      get '/facilities_api/v1/va', params: { type: 'bogus' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for query with services but no type' do
      get '/facilities_api/v1/va', params: { services: 'EyeCare' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for health query with unknown service' do
      get '/facilities_api/v1/va', params: { type: 'health', services: ['OilChange'] }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for benefits query with unknown service' do
      get '/facilities_api/v1/va', params: { type: 'benefits', services: ['Haircut'] }
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
        get '/facilities_api/v1/va', params: { lat: 33.298639, long: -111.789659, radius: 50 }
      end.to instrument('lighthouse.facilities.v1.request.faraday')
    end

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      bbox: [-74.730, 40.015, -73.231, 41.515],
                      page: 2
                    },
                    %w[
                      vc_0102V vc_0110V nca_808 nca_947 vha_526
                      vha_526QA vc_0109V vc_0857MVC vha_561GD vc_0132V
                    ]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64]
                    },
                    %w[
                      vha_648GI vba_348a vba_348 vc_0617V vba_348d
                      vha_648 vba_348h vha_648A4 nca_954 nca_907
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
                    %w[vba_348a vba_348 vba_348d vba_348h]

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
                      vha_644BY vc_0524V vba_345g vba_345 vha_644QA
                      vc_0517V vha_644GG vha_644 vha_644QB vha_644GH
                    ],
                    [
                      2.08, 7.68, 11.72, 18.3, 19.59,
                      19.71, 20.31, 21.05, 21.06, 22.78
                    ]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      lat: 33.298639,
                      long: -111.789659,
                      radius: 50
                    },
                    %w[
                      vha_644BY vc_0524V vba_345g vba_345 vha_644QA
                      vc_0517V vha_644GG vha_644 vha_644QB vha_644GH
                    ],
                    [
                      2.08, 7.68, 11.72, 18.3, 19.59,
                      19.71, 20.31, 21.05, 21.06, 22.78
                    ]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64],
                      lat: 33.298639,
                      long: -111.789659,
                      radius: 50
                    },
                    %w[
                      vha_648GI vba_348a vba_348 vc_0617V vba_348d
                      vha_648 vba_348h vha_648A4 nca_954 nca_907
                    ]

    it_behaves_like 'paginated request from params with expected IDs',
                    {
                      state: 'TX'
                    },
                    %w[
                      vc_0702V vc_0703V vc_0705V vc_0706V vc_0707V
                      vc_0708V vc_0710V vc_0711V vc_0712V vc_0714V
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
                          vha_526QA vc_0857MVC vha_630QA vha_630QB vha_632QA
                          vha_632QB
                        ],
                        [],
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
                        [],
                        false
      end
    end

    context 'params[:type] = health' do
      context 'params[:services] = [\'Covid19Vaccine\']', vcr: vcr_options.merge(
        cassette_name: 'facilities/mobile/covid'
      ) do
        let(:params) do
          {
            lat: 42.060906,
            long: -71.051868,
            type: 'health',
            services: ['Covid19Vaccine']
          }
        end

        before do
          Flipper.enable('facilities_locator_mobile_covid_online_scheduling', flipper)
          get '/facilities_api/v1/va', params:
        end

        context 'facilities_locator_mobile_covid_online_scheduling enabled' do
          let(:flipper) { true }

          it { expect(response).to be_successful }

          it 'is expected not to populate tmpCovidOnlineScheduling' do
            parsed_body['data']

            expect(parsed_body['data'][0]['attributes']['tmpCovidOnlineScheduling']).to be_truthy

            attributes_covid = parsed_body['data'].collect { |x| x['attributes']['tmpCovidOnlineScheduling'] }

            expect(attributes_covid).to eql([
                                              true,
                                              false,
                                              true,
                                              false,
                                              false,
                                              false,
                                              false,
                                              true,
                                              false,
                                              false
                                            ])
          end
        end

        context 'facilities_locator_mobile_covid_online_scheduling disabled' do
          let(:flipper) { false }

          it { expect(response).to be_successful }

          it 'is expected not to populate tmpCovidOnlineScheduling' do
            parsed_body['data']

            expect(parsed_body['data']).to all(
              a_hash_including(
                attributes: a_hash_including(tmpCovidOnlineScheduling: nil)
              )
            )
          end
        end
      end
    end
  end

  describe 'GET #show' do
    before do
      get '/facilities_api/v1/va/vha_648A4'
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
                  { service: 'Audiology',        new: kind_of(Float), established: kind_of(Float) },
                  { service: 'Dermatology',      new: kind_of(Float), established: kind_of(Float) },
                  { service: 'MentalHealthCare', new: kind_of(Float), established: kind_of(Float) },
                  { service: 'Ophthalmology',    new: kind_of(Float), established: kind_of(Float) },
                  { service: 'Optometry',        new: kind_of(Float), established: kind_of(Float) },
                  { service: 'PrimaryCare',      new: kind_of(Float), established: kind_of(Float) },
                  { service: 'SpecialtyCare',    new: kind_of(Float), established: kind_of(Float) }
                ],
                effectiveDate: '2022-01-23'

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
              distance: nil,
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
              operationalHoursSpecialInstructions: 'More hours are available for some services. ' \
                                                   'To learn more, call our main phone number. |',
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
                  MentalHealthCare
                  Ophthalmology
                  Optometry
                  Podiatry
                  PrimaryCare
                  SpecialtyCare
                ],
                lastUpdated: '2022-01-23'
              },
              uniqueId: '648A4',
              visn: '20',
              website: 'https://www.va.gov/portland-health-care/locations/portland-va-medical-center-vancouver/',
              tmpCovidOnlineScheduling: nil
            }
          }
        }
      )
    end
  end
end
