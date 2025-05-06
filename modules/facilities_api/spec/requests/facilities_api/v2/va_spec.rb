# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'paginated response from request body with expected IDs' do
  |request_params, ids, distances = [], mobile = nil|
  let(:params) { request_params }
  let(:request_host) { 'http://www.example.com' }

  context request_params do
    before do
      post '/facilities_api/v2/va', params:
    end

    it { expect(response).to be_successful }

    it "is expected to contain ids: #{ids}" do
      expect(parsed_body['data'].pluck('id')).to match(ids)
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
                                                         next_page: be_a(Integer).or(be_nil),
                                                         total_pages: be_a(Integer),
                                                         total_entries: be_a(Integer)
                                                       })
    end

    it 'is expected to include pagination links' do
      current_page = parsed_body[:meta][:pagination][:current_page]
      prev_page = parsed_body[:meta][:pagination][:prev_page]
      next_page = parsed_body[:meta][:pagination][:next_page]
      last_page = parsed_body[:meta][:pagination][:total_pages]
      prev_params = params.merge({ page: prev_page, per_page: 10 }).to_query
      next_params = params.merge({ page: next_page, per_page: 10 }).to_query
      prev_link = prev_page ? "#{request_host}/facilities_api/v2/va?#{prev_params}" : nil
      next_link = next_page ? "#{request_host}/facilities_api/v2/va?#{next_params}" : nil

      expect(parsed_body[:links]).to match(
        self: "#{request_host}/facilities_api/v2/va?#{params.merge({ page: current_page,
                                                                     per_page: 10 }).to_query}",
        first: "#{request_host}/facilities_api/v2/va?#{params.merge({ per_page: 10 }).to_query}",
        prev: prev_link,
        next: next_link,
        last: "#{request_host}/facilities_api/v2/va?#{params.merge({ page: last_page, per_page: 10 }).to_query}"
      )
    end
  end
end

vcr_options = {
  cassette_name: '/facilities/va/lighthouse',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe 'FacilitiesApi::V2::Va', team: :facilities, type: :request, vcr: vcr_options do
  subject(:parsed_body) { JSON.parse(response.body).with_indifferent_access }

  describe 'POST #search' do
    it 'returns 400 for invalid type parameter' do
      post '/facilities_api/v2/va', params: { type: 'bogus' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 200 for query with services but no type' do
      post '/facilities_api/v2/va', params: { services: 'EyeCare' }
      expect(response).to have_http_status(:ok)
    end

    it 'returns 400 for health query with unknown service' do
      post '/facilities_api/v2/va', params: { type: 'health', services: ['OilChange'] }
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 for benefits query with unknown service' do
      post '/facilities_api/v2/va', params: { type: 'benefits', services: ['Haircut'] }
      expect(response).to have_http_status(:bad_request)
    end

    it "sends a 'lighthouse.facilities.v2.request.faraday' notification to any subscribers listening" do
      allow(StatsD).to receive(:measure)

      expect(StatsD).to receive(:measure).with(
        'facilities.lighthouse.v2',
        kind_of(Numeric),
        hash_including(
          tags: ['facilities.lighthouse']
        )
      )

      expect do
        post '/facilities_api/v2/va', params: { lat: 33.298639, long: -111.789659, radius: 50 }
      end.to instrument('lighthouse.facilities.v2.request.faraday')
    end

    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      bbox: [-74.730, 40.015, -73.231, 41.515],
                      page: 2
                    },
                    %w[vc_0110V nca_808 vha_526 vha_526QA vc_0857MVC vha_561GD vc_0132V vha_630A4 vha_526GB vba_309]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64]
                    },
                    %w[vha_648GI vba_348a vba_348 vc_0617V vba_348d vha_648 vba_348h vha_648A4 nca_954 nca_907]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64],
                      type: 'health'
                    },
                    %w[vha_648GI vha_648 vha_648A4 vha_648GE]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64],
                      type: 'benefits'
                    },
                    %w[vba_348a vba_348 vba_348d vba_348h]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64],
                      type: 'benefits',
                      services: ['DisabilityClaimAssistance']
                    },
                    %w[vba_348]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      lat: 33.298639,
                      long: -111.789659
                    },
                    %w[vha_644BY vha_644GJ vc_0524V vba_345g vha_644GI vba_345 vha_644QA vc_0517V vha_644GG vha_644QB],
                    [2.08, 6.58, 7.68, 11.72, 16.75, 18.3, 19.59, 19.71, 20.31, 20.95]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      lat: 33.298639,
                      long: -111.789659,
                      radius: 50
                    },
                    %w[vha_644BY vha_644GJ vc_0524V vba_345g vha_644GI vba_345 vha_644QA vc_0517V vha_644GG vha_644QB],
                    [2.08, 6.58, 7.68, 11.72, 16.75, 18.3, 19.59, 19.71, 20.31, 20.95]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      bbox: [-122.786758, 45.451913, -122.440689, 45.64],
                      lat: 33.298639,
                      long: -111.789659,
                      radius: 50
                    },
                    %w[vha_648GI vba_348a vba_348 vc_0617V vba_348d vha_648 vba_348h vha_648A4 nca_954 nca_907]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      state: 'TX'
                    },
                    %w[nca_846 nca_851 nca_854 nca_877 nca_886 nca_916 nca_s1118 nca_s1119 nca_s1120 nca_s1121]
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      zip: 85_297
                    },
                    ['vha_644BY']
    it_behaves_like 'paginated response from request body with expected IDs',
                    {
                      ids: 'vha_442,vha_552,vha_552GB,vha_442GC,vha_442GB,vha_552GA,vha_552GD'
                    },
                    %w[vha_442 vha_442GB vha_442GC vha_552 vha_552GA vha_552GB vha_552GD]

    context 'params[:mobile]' do
      context 'mobile not passed' do
        it_behaves_like 'paginated response from request body with expected IDs',
                        {
                          bbox: [-74.730, 40.015, -73.231, 41.515],
                          page: 1
                        },
                        %w[vc_0106V vha_630 vba_306 vha_630GA vc_0133V vha_526GD vc_0105V vha_561GE vc_0109V vc_0102V]
      end

      context 'true' do
        it_behaves_like 'paginated response from request body with expected IDs',
                        {
                          mobile: true,
                          bbox: [-74.730, 40.015, -73.231, 41.515],
                          page: 1
                        },
                        %w[vha_526QA vc_0857MVC vha_630QA vha_630QB vha_632QA vha_632QB],
                        [],
                        true
      end

      context 'false' do
        it_behaves_like 'paginated response from request body with expected IDs',
                        {
                          mobile: false,
                          bbox: [-74.730, 40.015, -73.231, 41.515],
                          page: 1
                        },
                        %w[
                          vc_0106V vha_630 vha_630GA vc_0133V vha_526GD vc_0105V vha_561GE vc_0109V vc_0102V vc_0110V
                        ],
                        [],
                        false
      end
    end
  end

  describe 'GET #show' do
    context 'with all attributes' do
      before do
        get '/facilities_api/v2/va/vha_648A4'
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
                    {
                      'serviceName' => 'Audiology and speech',
                      'service' => 'audiology',
                      'serviceType' => 'health',
                      'new' => 53.0,
                      'established' => 28.0,
                      'effectiveDate' => '2024-07-29'
                    },
                    {
                      'serviceName' => 'Optometry',
                      'service' => 'optometry',
                      'serviceType' => 'health',
                      'new' => 56.0,
                      'established' => 17.0,
                      'effectiveDate' => '2024-07-29'
                    }
                  ],
                  'effectiveDate' => '2024-07-29'
                },
                address: {
                  physical: {
                    zip: '98661-3753',
                    city: 'Vancouver',
                    state: 'WA',
                    address1: '1601 East 4th Plain Boulevard'
                  }
                },
                classification: 'VA Medical Center (VAMC)',
                distance: nil,
                facilityType: 'va_health_facility',
                feedback: {
                  health: {
                    primaryCareUrgent: 0.699999988079071,
                    primaryCareRoutine: 0.7799999713897705
                  },
                  effectiveDate: '2024-02-08'
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
                name: 'Vancouver VA Medical Center',
                operatingStatus: {
                  code: 'NORMAL'
                },
                operationalHoursSpecialInstructions: ['More hours are available for some services. To learn more, ' \
                                                      'call our main phone number.'],
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
                  health: [
                    {
                      name: 'Addiction and substance use care',
                      serviceId: 'addiction',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/addiction'
                    },
                    {
                      name: 'Audiology and speech',
                      serviceId: 'audiology',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/audiology'
                    },
                    {
                      name: 'Dental/oral surgery',
                      serviceId: 'dental',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/dental'
                    },
                    {
                      name: 'Dermatology',
                      serviceId: 'dermatology',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/dermatology'
                    },
                    {
                      name: 'Veteran readiness and employment programs',
                      serviceId: 'employmentPrograms',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/employmentPrograms'
                    },
                    {
                      name: 'Gastroenterology',
                      serviceId: 'gastroenterology',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/gastroenterology'
                    },
                    {
                      name: 'Geriatrics',
                      serviceId: 'geriatrics',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/geriatrics'
                    },
                    {
                      name: 'Gynecology',
                      serviceId: 'gynecology',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/gynecology'
                    },
                    {
                      name: 'HIV/hepatitis care',
                      serviceId: 'hiv',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/hiv'
                    },
                    {
                      name: 'Laboratory and pathology',
                      serviceId: 'laboratory',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/laboratory'
                    },
                    {
                      name: 'MentalHealth',
                      serviceId: 'mentalHealth',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/mentalHealth'
                    },
                    {
                      name: 'Nutrition, food, and dietary care',
                      serviceId: 'nutrition',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/nutrition'
                    },
                    {
                      name: 'Ophthalmology',
                      serviceId: 'ophthalmology',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/ophthalmology'
                    },
                    {
                      name: 'Optometry',
                      serviceId: 'optometry',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/optometry'
                    },
                    {
                      name: 'Orthopedics',
                      serviceId: 'orthopedics',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/orthopedics'
                    },
                    {
                      name: 'Physical therapy, occupational therapy and kinesiotherapy',
                      serviceId: 'physicalTherapy',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/physicalTherapy'
                    },
                    {
                      name: 'Plastic and reconstructive surgery',
                      serviceId: 'plasticSurgery',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/plasticSurgery'
                    },
                    {
                      name: 'Podiatry',
                      serviceId: 'podiatry',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/podiatry'
                    },
                    {
                      name: 'Primary care',
                      serviceId: 'primaryCare',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/primaryCare'
                    },
                    {
                      name: 'Prosthetics and rehabilitation',
                      serviceId: 'prosthetics',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/prosthetics'
                    },
                    {
                      name: 'PTSD care',
                      serviceId: 'ptsd',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/ptsd'
                    },
                    {
                      name: 'Radiology',
                      serviceId: 'radiology',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/radiology'
                    },
                    {
                      name: 'Rehabilitation and extended care',
                      serviceId: 'rehabilitation',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/rehabilitation'
                    },
                    {
                      name: 'Spinal cord injuries and disorders',
                      serviceId: 'spinalInjury',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/spinalInjury'
                    },
                    {
                      name: 'Returning service member care',
                      serviceId: 'transitionCounseling',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/transitionCounseling'
                    },
                    {
                      name: 'Travel reimbursement',
                      serviceId: 'travelReimbursement',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/travelReimbursement'
                    },
                    {
                      name: 'Blind and low vision rehabilitation',
                      serviceId: 'vision',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/vision'
                    },
                    {
                      name: 'Whole health',
                      serviceId: 'wholeHealth',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/wholeHealth'
                    },
                    {
                      name: 'Women Veteran care',
                      serviceId: 'womensHealth',
                      link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services/womensHealth'
                    }
                  ],
                  link: 'https://sandbox-api.va.gov/services/va_facilities/v1/facilities/vha_648A4/services',
                  lastUpdated: '2024-04-23'
                },
                uniqueId: '648A4',
                visn: '20',
                website: 'https://www.va.gov/portland-health-care/locations/vancouver-va-medical-center/',
                tmpCovidOnlineScheduling: nil
              }
            }
          }
        )
      end
    end

    context 'with missing attributes' do
      before do
        get '/facilities_api/v2/va/vha_506GG'
      end

      it { expect(response).to be_successful }

      it do
        expect(subject).to match(
          {
            data: {
              id: 'vha_506GG',
              type: 'facility',
              attributes: {
                access: {
                  health: [],
                  effectiveDate: ''
                },
                address: [],
                classification: 'Primary Care CBOC',
                distance: nil,
                facilityType: 'va_health_facility',
                feedback: [],
                hours: [],
                id: 'vha_506GG',
                lat: 41.066235,
                long: -83.619621,
                mobile: false,
                name: 'Findlay VA Clinic',
                operatingStatus: [],
                operationalHoursSpecialInstructions: nil,
                phone: [],
                services: [],
                uniqueId: '506GG',
                visn: '10',
                website: nil,
                tmpCovidOnlineScheduling: nil
              }
            }
          }
        )
      end
    end
  end
end
