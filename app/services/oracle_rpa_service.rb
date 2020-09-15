# frozen_string_literal: true
require 'watir'
require 'selenium-webdriver'

# This service submits a form to the existing IRIS Oracle page
class OracleRPAService
  def initialize(claim)
    @claim = claim
  end

  def submit_form
    browser = Watir::Browser.new :chrome, args: %w[--headless --no-sandbox --disable-dev-shm-usage]
    browser.goto 'https://iris--tst.custhelp.com/app/ask'
    0
  end
end
