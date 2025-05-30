class AddPolymorphicIndexToRoles < ActiveRecord::Migration[7.1]
  def change
    add_index :roles, [:roleable_type, :roleable_id], name: 'index_roles_on_roleable'
  end
end