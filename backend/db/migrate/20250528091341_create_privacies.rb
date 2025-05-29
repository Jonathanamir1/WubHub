class CreatePrivacies < ActiveRecord::Migration[7.1]
  def change
    create_table :privacies do |t|
      t.references :user, null: false, foreign_key: true
      t.references :privatable, polymorphic: true, null: false, index: true
      t.string :level, null: false, default: 'inherited'
      
      t.timestamps
    end
    
    # Add unique constraint to ensure one privacy record per resource
    add_index :privacies, [:privatable_type, :privatable_id], unique: true
  end
end