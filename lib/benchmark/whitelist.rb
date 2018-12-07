# frozen_string_literal: true

module Benchmark
  class Whitelist
    # This array of paths must remain identical to its sibling whitelist maintained
    # in the department-of-veterans-affairs/vets-website repository at:
    #   https://github.com/department-of-veterans-affairs/vets-website/blob/master/src/platform/monitoring/frontend-metrics/whitelisted-paths.js
    #
    # Any changes made must be made to both.
    #
    WHITELIST = ['/', '/disability/', '/find-locations/', '/disability/how-to-file-claim/'].freeze

    attr_reader :tags

    # @param tags [Array<String>] An array of string tag names. Tags must be in the key:value
    #   format in the string.  For example:
    #   ['page_id:/disability/', 'page_id:/facilities/']
    #
    def initialize(tags)
      @tags = tags
    end

    # Ensures that the supplied tags are in the defined WHITELIST array.  If any tag
    # is not on the WHITELIST, it raises a Common::Exceptions::Forbidden error.
    #
    # @return [Array<String>] The array of tags that initialized the class
    # @return [Common::Exceptions::Forbidden] Raises error if a tag is not whitelisted
    #
    def authorize!
      tags.each do |tag|
        whitelisted? page_in(tag)
      end
    end

    private

    def page_in(tag)
      tag.split(':').last
    end

    def whitelisted?(page)
      unless WHITELIST.include?(page)
        raise Common::Exceptions::Forbidden.new(
          detail: "Page at #{page} is not whitelisted for performance monitoring.",
          source: 'Benchmark::Performance'
        )
      end
    end
  end
end
