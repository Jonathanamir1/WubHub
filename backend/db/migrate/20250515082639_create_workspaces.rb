class CreateWorkspaces < ActiveRecord::Migration[7.1]
  def change
    create_table :workspaces do |t|
      t.string :name
      t.text :description
      t.string :workspace_type
      t.string :visibility
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
