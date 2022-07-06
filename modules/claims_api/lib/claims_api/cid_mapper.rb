# frozen_string_literal: true

# Maps a given 'cid' (OKTA Client Id) to a known Lighthouse Benefits Claims Api consumer
module ClaimsApi
  class CidMapper
    CID_MAPPINGS = {
      '0oa9uf05lgXYk6ZXn297' => 'VA TurboClaim',
      '0oa66qzxiq37neilh297' => 'ETK Veteran’s Benefits'
    }.freeze

    def initialize(cid:)
      @cid = cid
    end

    def name
      return 'no cid' if @cid.nil?
      return 'no cid' if @cid.strip.empty?

      value = CID_MAPPINGS[@cid]
      return @cid.truncate(10) if value.nil?

      value
    end
  end
end
