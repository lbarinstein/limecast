# == Schema Information
# Schema version: 20090123214455
#
# Table name: taggings
#
#  id         :integer(4)    not null, primary key
#  tag_id     :integer(4)    
#  podcast_id :integer(4)    
#

class Tagging < ActiveRecord::Base
  belongs_to :podcast
  belongs_to :tag

  before_save :map_to_different_tag

  validates_uniqueness_of :tag_id, :scope => :podcast_id, :message => "has already been used on this Podcast"


  def map_to_different_tag
    return if self.tag.nil?

    self.tag = self.tag.map_to until self.tag.map_to.nil?
  end
end
