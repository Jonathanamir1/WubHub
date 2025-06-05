class Container < ApplicationRecord
  belongs_to :workspace
  belongs_to :parent_container
end
