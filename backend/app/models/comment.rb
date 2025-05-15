class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :track_version
end
