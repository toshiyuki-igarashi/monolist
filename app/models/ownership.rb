class Ownership < ApplicationRecord
  belongs_to :user
  belongs_to :item

  # print all ownership for maintenance
  def self.show_all                                                                                           
    self.all.each do |ownership|
      puts "id:#{ownership.id}, type:#{ownership.type}, user:#{ownership.user} item:#{ownership.item}"
    end                                                                
    nil                                                                                 
  end
end
