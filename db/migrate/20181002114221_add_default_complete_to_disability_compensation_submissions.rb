class AddDefaultCompleteToDisabilityCompensationSubmissions < ActiveRecord::Migration[4.2]
	def change
		change_column_default :disability_compensation_submissions, :complete, false
	end
end
