class ConvertRolesToPolymorphic < ActiveRecord::Migration[7.1]
  def change
    add_column :roles, :roleable_id, :integer
    add_column :roles, :roleable_type, :string

  end
end
