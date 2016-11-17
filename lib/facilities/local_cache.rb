# frozen_string_literal: true

module Facilities
  class LocalStore
    attr_reader :adapter

    GIS_CHECK_FREQUENCY = 1.hour
    BATCH_SIZE = 1000.0
    OPEN_TIMEOUT = 2
    REQUEST_TIMEOUT = 6
    Pointer = Struct.new(:x, :y, :facility)

    def initialize(url, type, adapter)
      @url = url
      @adapter = adapter
      @mutex = Mutex.new
      @last_check = Time.new(0)
      @last_gis_update = 0
      @conn = Faraday.new(:url => @url) do |conn|
        conn.options.open_timeout = OPEN_TIMEOUT
        conn.options.timeout = REQUEST_TIMEOUT
        conn.response :logger
        # TODO conn.use :breakers
        conn.adapter Faraday.default_adapter 
      end
      check_for_freshness
    end

    def get(id)
      check_for_freshness
      @mutex.synchronize do
        return @index[id]
      end
    end

    def query(bbox) 
      check_for_freshness
      @mutex.synchronize do
        @coordinates.select(&(within bbox)).sort_by(&(dist_from_center bbox)).map { |p| p.facility }
      end
    end

    #def query_n(bbox)
    #  coordinates.sort_by(&dist_from_center bbox)
    #end

    def within(bbox)
      x_min, x_max = bbox[0] < bbox[2] ? [bbox[0], bbox[2]] : [bbox[2], bbox[0]]
      y_min, y_max = bbox[1] < bbox[3] ? [bbox[1], bbox[3]] : [bbox[3], bbox[1]]
      lambda do |point|
        return false if point.x.nil? || point.y.nil?
        x_min < point.x && point.x < x_max &&
        y_min < point.y && point.y < y_max
      end
    end

    def dist_from_center(bbox)
      center_x = (bbox[0] + bbox[2]) / 2.0
      center_y = (bbox[1] + bbox[3]) / 2.0
      lambda do |point|
        Math.sqrt((point.x - center_x)**2 + (point.y - center_y)**2)
      end
    end

    def check_for_freshness
      puts Time.current
      puts @last_check
      return unless Time.current > (@last_check + GIS_CHECK_FREQUENCY)
      @mutex.synchronize do
        puts "gonna check"
        return unless Time.current > (@last_check + GIS_CHECK_FREQUENCY)
        @last_check = Time.current
        current_edit = gis_edit_date
        puts current_edit
        puts @last_gis_update
        return if current_edit == @last_gis_update
        refresh
        @last_gis_update = current_edit
      end
    end

    def gis_edit_date
      puts @url
      response = @conn.get '', { :f => 'json' }
      return nil unless response.status == 200
      result = JSON.parse(response.body)
      result&.[]('editingInfo')&.[]('lastEditDate')
    end

    def refresh
       puts 'refresh'
       query_url = [@url, 'query'].join('/')
       count_params = {
         where: '1=1',
         returnCountOnly: true,
         f: 'json'
       }
       response = @conn.get query_url, count_params
       # TODO Error handling
       count = JSON.parse(response.body)&.[]('count')
       params = {
         where: '1=1',
         inSR: 4326,
         outSR: 4326,
         returnGeometry: true,
         outFields: '*',
         f: 'json'
       }
       max = (count / BATCH_SIZE).ceil - 1
       facilities = []
       (0..max).each do |i|
         params['resultOffset'] = (i * BATCH_SIZE).to_i
         params['resultRecordCount'] = BATCH_SIZE.to_i
         response = @conn.get query_url, params
         # TODO Error handling
         parse(response.body, facilities)
       end
       index(facilities)
    end

    def parse(response, facilities)
      result = JSON.parse(response)
      if result['error']
        Rails.logger.error "GIS returned error: #{result['error']['code']}, message: #{result['error']['message']}"
      end
      result['features'].each do |f|
        facilities << @adapter.from_gis(f)
      end
    end

    def index(facilities)
      new_index = facilities.each_with_object({}) do |f, index|
        index[f.unique_id] = f
      end
      new_coordinates = facilities.each_with_object([]) do |f, coordinates|
        coordinates << Pointer.new(f.long, f.lat, f)
      end
      @index = new_index
      @coordinates = new_coordinates
    end

  end
end
