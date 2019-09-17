# frozen_string_literal: true

require 'rails_helper'
require 'cgi'
require 'uri'

RSpec.describe 'Facilities API endpoint', type: :request do
  include SchemaMatchers

  let(:base_query_path) { '/services/va_facilities/v0/facilities' }
  let(:pdx_bbox) { '?bbox[]=-122.440689&bbox[]=45.451913&bbox[]=-122.786758&bbox[]=45.64' }
  let(:empty_bbox) { '?bbox[]=-122&bbox[]=45&bbox[]=-122&bbox[]=45' }
  let(:lat_long) { '?lat=45.451913&long=-122.440689' }
  let(:zip) { '?zip=97204' }
  let(:ids_query) do
    ids = setup_pdx.map { |facility| facility.facility_type_prefix + '_' + facility.unique_id }
    "?ids=#{ids.join(',')}"
  end

  let(:setup_pdx) do
    %w[vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348 vba_348a vba_348d vba_348e vba_348h].map { |id| create id }
  end
  let(:accept_json) { { 'HTTP_ACCEPT' => 'application/json' } }
  let(:accept_geojson) { { 'HTTP_ACCEPT' => 'application/vnd.geo+json' } }
  let(:accept_csv) { { 'HTTP_ACCEPT' => 'text/csv' } }

  def parse_link_header(header)
    links = header.split(',').map(&:strip)
    links = links.map { |x| x.split(';').map(&:strip).reverse }
    links.each_with_object({}) do |(f, s), h|
      k = f.sub('rel="', '').sub('"', '')
      v = query_params(s.tr('<>', ''))
      h[k] = v
    end
  end

  def query_params(url)
    CGI.parse(URI.parse(url).query)
  end

  context 'when requesting JSON API format' do
    it 'responds to GET #show for VHA prefix' do
      create :vha_648A4
      get base_query_path + '/vha_648A4', params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq('vha_648A4')
    end

    it 'responds to GET #index with bbox' do
      setup_pdx
      get base_query_path + pdx_bbox, params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(10)
      expect(json['meta']['distances']).to eq([])
    end

    it 'responds to GET #index with lat/long' do
      setup_pdx
      get base_query_path + lat_long, params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(10)
      expect(json['meta']['distances'].length).to eq(10)
    end

    it 'responds to GET #index with ids sorted by distance from lat/long' do
      setup_pdx
      get "#{base_query_path}#{ids_query}&lat=45.451913&long=-122.440689", params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(10)
      expect(json['meta']['distances'].length).to eq(10)
    end

    it 'responds to GET #index with zip' do
      setup_pdx
      get base_query_path + zip, params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(4)
      expect(json['meta']['distances']).to eq([])
    end

    it 'responds to GET #index with zip+4' do
      setup_pdx
      get base_query_path + zip + '-3432', params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(4)
      expect(json['meta']['distances']).to eq([])
    end

    it 'responds such that record and distance metadata IDs match up' do
      setup_pdx
      get base_query_path + lat_long, params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      record_ids = json['data'].map { |x| x['id'] }
      distance_ids = json['meta']['distances'].map { |x| x['id'] }
      expect(record_ids).to match_array(distance_ids)
    end

    it 'responds to GET #index with ids' do
      get base_query_path + ids_query, params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(10)
    end

    it 'responds to GET #index with one id' do
      first_pdx = setup_pdx[1]
      id_query = "?ids=#{first_pdx.facility_type_prefix}_#{first_pdx.unique_id}"
      get base_query_path + id_query, params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
    end

    it 'responds to GET #index with a malformed id' do
      ids_query_with_extra = ids_query + ',0618B'
      get base_query_path + ids_query_with_extra, params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(10)
    end

    it 'responds to GET #index with ids where one does not exist' do
      ids_query_with_extra = ids_query + ',vc_0618B'
      get base_query_path + ids_query_with_extra, params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(10)
    end

    it 'responds to GET #index with state code' do
      setup_pdx
      get base_query_path, params: 'state=WA', headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(2)
    end

    it 'responds with pagination links' do
      setup_pdx
      get base_query_path + pdx_bbox, params: nil, headers: accept_json
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json).to have_key('links')
      links = json['links']
      expect(links).to have_key('self')
      expect(links).to have_key('first')
      expect(links).to have_key('last')
      expect(links).to have_key('prev')
      expect(links).to have_key('next')
    end

    it 'responds with pagination metadata' do
      setup_pdx
      get base_query_path + pdx_bbox, params: nil, headers: accept_json
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json).to have_key('meta')
      expect(json['meta']).to have_key('pagination')
      pagination = json['meta']['pagination']
      expect(pagination).to have_key('current_page')
      expect(pagination).to have_key('per_page')
      expect(pagination).to have_key('total_pages')
      expect(pagination).to have_key('total_entries')
    end

    it 'paginates according to parameters' do
      setup_pdx
      get base_query_path + pdx_bbox + '&page=2&per_page=3', params: nil, headers: accept_json
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(3)
      links = json['links']
      expect(query_params(links['self'])['page']).to eq(['2'])
      expect(query_params(links['self'])['per_page']).to eq(['3'])
      pagination = json['meta']['pagination']
      expect(pagination['current_page']).to eq(2)
      expect(pagination['per_page']).to eq(3)
      expect(pagination['total_pages']).to eq(4)
      expect(pagination['total_entries']).to eq(10)
    end

    it 'defaults to the BaseFacility pagination per_page if no param is provided' do
      create_list(:generic_vba, 30)
      get base_query_path + '?zip=97204', params: nil, headers: accept_json
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(20)
      links = json['links']
      expect(query_params(links['next'])['per_page']).to eq([BaseFacility.per_page.to_s])
      pagination = json['meta']['pagination']
      expect(pagination['per_page']).to eq(BaseFacility.per_page)
    end

    it 'paginates empty result set' do
      setup_pdx
      get base_query_path + empty_bbox, params: nil, headers: accept_json
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(0)
      links = json['links']
      expect(query_params(links['last'])['page']).to eq(['1'])
      pagination = json['meta']['pagination']
      expect(pagination['total_pages']).to eq(1)
      expect(pagination['total_entries']).to eq(0)
    end
  end

  context 'when requesting GeoJSON format' do
    it 'responds to GET #show for VHA prefix' do
      create :vha_648A4
      get base_query_path + '/vha_648A4', params: nil, headers: accept_geojson
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['type']).to eq('Feature')
      expect(json['properties']['id']).to eq('vha_648A4')
      expect(response.headers['Content-Type']).to eq 'application/vnd.geo+json; charset=utf-8'
    end

    it 'responds to GET #index with bbox' do
      setup_pdx
      get base_query_path + pdx_bbox, params: nil, headers: accept_geojson
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['type']).to eq('FeatureCollection')
      expect(json['features'].length).to eq(10)
      expect(response.headers['Content-Type']).to eq 'application/vnd.geo+json; charset=utf-8'
    end

    it 'responds with pagination link header' do
      setup_pdx
      get base_query_path + pdx_bbox, params: nil, headers: accept_geojson
      expect(response).to be_successful
      expect(response.headers['Link']).to be_present
      parsed = parse_link_header(response.headers['Link'])
      expect(parsed).to have_key('self')
      expect(parsed).to have_key('first')
      expect(parsed).to have_key('last')
      expect(parsed).not_to have_key('prev')
      expect(parsed).not_to have_key('next')
    end

    it 'paginates according to parameters' do
      setup_pdx
      get base_query_path + pdx_bbox + '&page=2&per_page=3', params: nil, headers: accept_geojson
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json['type']).to eq('FeatureCollection')
      expect(json['features'].length).to eq(3)
      expect(response.headers['Link']).to be_present
      parsed = parse_link_header(response.headers['Link'])
      expect(parsed['self']['page']).to eq(['2'])
      expect(parsed['first']['page']).to eq(['1'])
      expect(parsed['last']['page']).to eq(['4'])
      expect(parsed['prev']['page']).to eq(['1'])
      expect(parsed['next']['page']).to eq(['3'])
    end

    it 'paginates empty result set' do
      setup_pdx
      get base_query_path + empty_bbox, params: nil, headers: accept_geojson
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json['type']).to eq('FeatureCollection')
      expect(json['features'].length).to eq(0)
      expect(response.headers['Link']).to be_present
      parsed = parse_link_header(response.headers['Link'])
      expect(parsed['self']['page']).to eq(['1'])
      expect(parsed['first']['page']).to eq(['1'])
      expect(parsed['last']['page']).to eq(['1'])
    end
  end

  context 'when requesting all facilities' do
    it 'responds to GeoJSON format' do
      setup_pdx
      create :dod_001
      get base_query_path + '/all', params: nil, headers: accept_geojson
      expect(response).to be_successful
      expect(response.headers['Content-Type']).to eq 'application/vnd.geo+json; charset=utf-8'
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['type']).to eq('FeatureCollection')
    end

    it 'responds to CSV format' do
      setup_pdx
      create :dod_001
      get base_query_path + '/all', params: nil, headers: accept_csv
      expect(response).to be_successful
      expect(response.headers['Content-Type']).to eq 'text/csv'
      expect(response.body).to be_a(String)
    end
  end

  context 'with invalid request parameters' do
    it 'returns 400 for missing bbox or ids' do
      get base_query_path
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for nonsense bbox' do
      get base_query_path + '?bbox[]=everywhere'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-array bbox' do
      get base_query_path + '?bbox=-90,180,45,80'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for too many elements' do
      get base_query_path + '?bbox[]=-45&bbox[]=-45&bbox[]=45&bbox=45&bbox=100'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for not enough elements' do
      get base_query_path + '?bbox[]=-45&bbox[]=-45&bbox[]=45'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for non-numeric elements' do
      get base_query_path + '?bbox[]=-45&bbox[]=-45&bbox[]=45&bbox=abc'
      expect(response).to have_http_status(:bad_request)
    end
    it 'responds to GET #index with a malformed zip' do
      setup_pdx
      get base_query_path + '?zip=-3432', params: nil, headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for invalid type parameter' do
      get base_query_path + pdx_bbox + '&type=bogus'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for query with services but no type' do
      get base_query_path + pdx_bbox + '&services[]=EyeCare'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for health query with unknown service' do
      get base_query_path + pdx_bbox + '&type=health&services[]=OilChange'
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for an invalid state code' do
      get base_query_path, params: 'state=meow', headers: accept_json
      expect(response).to have_http_status(:bad_request)
    end
    it 'returns 400 for more than one distance location param type' do
      get base_query_path + pdx_bbox + '&state=FL' + '&type=benefits&services[]=DisabilityClaimAssistance'

      json = JSON.parse(response.body)
      expect(json['errors'].first).to eq(
        'You may only use ONE of these distance query parameter sets: lat/long, zip, state, or bbox'
      )

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'mobile flag' do
    it 'responds with a boolean mobile flag for VHA facilities' do
      create :vha_648A4
      get base_query_path + '/vha_648A4', params: nil, headers: accept_json
      expect(response).to be_successful
      expect(response.body).to be_a(String)
      json = JSON.parse(response.body)
      expect(json['data']['attributes']['mobile']).to eq(false)
      expect(json['data']['attributes']['mobile']).to_not be_nil
    end

    it 'responds with null mobile flag for non-VHA facilities' do
      create :nca_907
      create :vba_348
      create :vc_0617V

      get base_query_path + lat_long, params: nil, headers: accept_json

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)
      nca = json['data'][0]
      vba = json['data'][1]
      vc = json['data'][2]

      expect(nca['mobile']).to be_nil
      expect(vba['mobile']).to be_nil
      expect(vc['mobile']).to be_nil
    end
  end
end
