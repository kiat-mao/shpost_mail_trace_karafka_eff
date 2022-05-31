class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  before_create do
    if self.respond_to? :created_day
      self.created_day = self.created_at.strftime("%d")
    end
    if self.respond_to? :created_date
    	self.created_date = "#{self.created_at.strftime('%Y')}#{self.created_at.strftime('%m')}"
    end
  end
end
