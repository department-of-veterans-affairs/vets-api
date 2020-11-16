# frozen_string_literal: true

require 'watir'
require 'selenium-webdriver'

module Ask
  module Iris
    class WatirConfig
      WIDTH = 1024
      HEIGHT = 728
      def initialize(uri)
        @browser = Watir::Browser.new :chrome, args: %w[--no-sandbox --disable-dev-shm-usage]
        @browser.goto uri
        # Width must be at least 1024 or else watir will not find field on the far right side of the form
        @browser.window.resize_to WIDTH, HEIGHT
      end

      def click_button_by_id(button_id)
        @browser.button(id: button_id).click
      end

      def click_button_by_text(button_text)
        @browser.button(text: button_text).click
      end

      def click_link(link_text)
        @browser.link(visible_text: link_text).click
      end

      def select_dropdown_by_text(name, text)
        @browser.select_list(name: name).option(text: text).select
      end

      def select_dropdown_by_value(name, value)
        @browser.select_list(name: name).option(value: value).select
      end

      def set_text_area(name, value)
        @browser.textarea(name: name).set value
      end

      def set_text_field(name, value)
        @browser.text_field(name: name).set value
      end

      def tab
        @browser.send_keys :tab
      end

      def set_yes_no_radio(name, value)
        if value.eql? true
          @browser.radio(name: name, value: '1').set
        else
          @browser.radio(name: name, value: '0').set
        end
      end

      def get_text_from_element(tag, matcher)
        @browser.element(tag_name: tag, visible_text: matcher).inner_text
      end
    end
  end
end
