require_dependency 'facilities/client'

class FacilitiesController < ApplicationController

  skip_before_action :authenticate

end
