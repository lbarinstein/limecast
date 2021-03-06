# == Schema Information
# Schema version: 20100504173954
#
# Table name: statistics
#
#  id                                  :integer(4)    not null, primary key
#  podcasts_count                      :integer(4)    
#  podcasts_found_by_admins_count      :integer(4)    
#  podcasts_found_by_nonadmins_count   :integer(4)    
#  users_count                         :integer(4)    
#  users_confirmed_count               :integer(4)    
#  users_unconfirmed_count             :integer(4)    
#  reviews_count                       :integer(4)    
#  created_at                          :datetime      
#  podcasts_from_trackers_count        :integer(4)    
#  podcasts_with_buttons_count         :integer(4)    
#  podcasts_on_google_first_page_count :integer(4)    
#  users_admins_count                  :integer(4)    
#  users_nonadmins_count               :integer(4)    
#  authors_count                       :integer(4)    
#  reviews_by_admins_count             :integer(4)    
#  reviews_by_nonadmins_count          :integer(4)    
#

class Statistic < ActiveRecord::Base
  named_scope :by_month_and_year, lambda { { :group => "DATE_FORMAT(created_at, '%b %y')", :order => "created_at DESC" } }

  # Returns an array of Statistics; one for each month, and
  # each one is the earliest created for that month.
  def self.all_earliest_days_of_each_month
    all.group_by { |stat|
      stat.created_at.strftime("%b %y")
    }.map { |month_and_year, stats|
      stats.sort_by(&:created_at).first
    }
  end
end
